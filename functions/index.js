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
			`You are a produce freshness expert. Analyze the food/produce in the image and respond with ONLY a valid JSON object (no markdown, no explanation). The JSON must have exactly these fields:
{
  "name_en": "English name of the produce",
  "name_vn": "Vietnamese name of the produce",
  "status": "TƯƠI or HỎNG",
  "days_left": <integer number of days>,
  "advice_en": "Brief storage/consumption advice in English",
  "advice_vn": "Lời khuyên ngắn gọn bằng tiếng Việt"
}`;
		const resultText = await analyzeImageBase64(image, prompt, GEMINI_API_KEY.value());
		logger.info("Gemini raw response:", resultText);
		// Clean up markdown code fences if present
		const cleanText = resultText.replace(/```json|```/g, "").trim();
		let parsed = JSON.parse(cleanText);
		// If Gemini returned an array, take the first element
		const json = Array.isArray(parsed) ? (parsed[0] || {}) : parsed;
		logger.info("Parsed JSON:", json);

		const nameEn = json.name_en === "undefined" || !json.name_en ? "Unknown" : json.name_en;
		const nameVn = json.name_vn === "undefined" || !json.name_vn ? "" : json.name_vn;
		const status = json.status === "undefined" || !json.status ? "Unknown" : json.status;
		const daysLeft = isNaN(parseInt(json.days_left)) ? 0 : parseInt(json.days_left);
		const adviceEn = json.advice_en === "undefined" || !json.advice_en ? "No advice" : json.advice_en;
		const adviceVn = json.advice_vn === "undefined" || !json.advice_vn ? "" : json.advice_vn;

		return {
			name: nameEn,
			name_vn: nameVn,
			status: status,
			days_left: daysLeft,
			advice_en: adviceEn,
			advice_vn: adviceVn,
		};
	} catch (e) {
		logger.error(e);
		return {
			name: "Error",
			name_vn: "Lỗi",
			status: "Unknown",
			days_left: 0,
			advice_en: e.message || String(e),
			advice_vn: e.message || String(e),
		};
	}
});

// listModels: Trả về danh sách các model khả dụng để debug
exports.listModels = onCall({ secrets: [GEMINI_API_KEY] }, async (request) => {
	try {
		const url = `https://generativelanguage.googleapis.com/v1beta/models?key=${GEMINI_API_KEY.value()}`;
		const response = await fetch(url);
		const data = await response.json();
		return data;
	} catch (e) {
		logger.error(e);
		return { error: e.message };
	}
});

// scanReceipt: Nhận ảnh base64, gọi Gemini, trả về mảng JSON
exports.scanReceipt = onCall({ secrets: [GEMINI_API_KEY] }, async (request) => {
	try {
		const { image } = request.data;
		if (!image) throw new Error("Missing image");
		const prompt =
			"OCR receipt. JSON ARRAY: name_en, name_vn, quantity, unit, suggested_days (int), type. No markdown.";
		const resultText = await analyzeImageBase64(image, prompt, GEMINI_API_KEY.value());
		logger.info("Gemini OCR response:", resultText);
		const cleanText = resultText.replace(/```json|```/g, "").trim();
		const parsed = JSON.parse(cleanText);
		logger.info("Parsed OCR JSON:", parsed);
		return (Array.isArray(parsed) ? parsed : []).map((item) => {
			return {
				name: item.name_en || "Unknown",
				name_vn: item.name_vn || "",
				quantity: item.quantity || 1,
				unit: item.unit || "item",
				suggested_days: item.suggested_days || 7,
				type: item.type || "Other",
			};
		});
	} catch (e) {
		logger.error(e);
		return [];
	}
});
