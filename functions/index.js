/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const { setGlobalOptions } = require("firebase-functions");
const { onCall } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { analyzeImageBase64 } = require("./gemini");
const { defineSecret } = require("firebase-functions/params");

// Định nghĩa secret Gemini API Key
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });


// analyzeImage: Nhận ảnh base64, gọi Gemini, trả về kết quả JSON
exports.analyzeImage = onCall({ secrets: [GEMINI_API_KEY] }, async (request) => {
	try {
		const { image } = request.data;
		if (!image) throw new Error("Missing image");
		// Prompt cho Gemini
		const prompt =
			"Analyze produce. JSON only: name_en, name_vn, status (TƯƠI/HỎNG), days_left (int), advice_en, advice_vn.";
			const resultText = await analyzeImageBase64(image, prompt, process.env.GEMINI_API_KEY);
		const json = JSON.parse(resultText.replace(/```json|```/g, "").trim());
		return {
			name: `${json.name_en} (${json.name_vn})`,
			status: json.status,
			days_left: json.days_left,
			advice: `🇬🇧 ${json.advice_en}\n🇻🇳 ${json.advice_vn}`,
		};
	} catch (e) {
		logger.error(e);
		return {
			name: "Lỗi",
			status: "Unknown",
			days_left: 0,
			advice: e.message || String(e),
		};
	}
});

// scanReceipt: Nhận ảnh base64, gọi Gemini, trả về mảng JSON
exports.scanReceipt = onCall({ secrets: [GEMINI_API_KEY] }, async (request) => {
	try {
		const { image } = request.data;
		if (!image) throw new Error("Missing image");
		const prompt =
			"OCR receipt. JSON ARRAY: name_en, name_vn, quantity, unit, suggested_days (int), type. No markdown.";
			const resultText = await analyzeImageBase64(image, prompt, process.env.GEMINI_API_KEY);
		const parsed = JSON.parse(resultText.replace(/```json|```/g, "").trim());
		return parsed.map((item) => {
			let name = item.name_en || "Unknown";
			if (item.name_vn) name += ` / ${item.name_vn}`;
			return {
				name,
				quantity: item.quantity,
				unit: item.unit,
				suggested_days: item.suggested_days,
				type: item.type,
			};
		});
	} catch (e) {
		logger.error(e);
		return [];
	}
});
