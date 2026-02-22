const { setGlobalOptions } = require("firebase-functions");
const { onCall } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { analyzeImageBase64 } = require("./gemini");
const { defineSecret } = require("firebase-functions/params");

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

setGlobalOptions({ maxInstances: 10 });

// analyzeImage: Check freshness of produce
exports.analyzeImage = onCall({ secrets: [GEMINI_API_KEY] }, async (request) => {
	try {
		const { image } = request.data;
		if (!image) throw new Error("Missing image");

		const prompt =
			`You are a produce freshness expert. Analyze the food/produce in the image and respond with ONLY a valid JSON object (no markdown, no explanation). Use ONLY English for status field. The JSON must have exactly these fields:
{
  "name_en": "English name of the produce",
  "name_vn": "Vietnamese name of the produce",
  "status": "Fresh or Warning or Bad",
  "status_vn": "Tươi or Cảnh báo or Hỏng",
  "days_left": <integer number of days left>,
  "advice_en": "Brief storage/consumption advice in English",
  "advice_vn": "Lời khuyên ngắn gọn bằng tiếng Việt"
}`;

		const resultText = await analyzeImageBase64(image, prompt, GEMINI_API_KEY.value());
		logger.info("Gemini raw response:", resultText);

		const cleanText = resultText.replace(/```json|```/g, "").trim();
		const parsed = JSON.parse(cleanText);
		const json = Array.isArray(parsed) ? (parsed[0] || {}) : parsed;
		logger.info("Parsed JSON:", json);

		const nameEn = json.name_en || "Unknown";
		const nameVn = json.name_vn || "";
		const status = json.status || "Unknown";
		const statusVn = json.status_vn || "";
		const daysLeft = isNaN(parseInt(json.days_left)) ? 0 : parseInt(json.days_left);
		const adviceEn = json.advice_en || "No advice";
		const adviceVn = json.advice_vn || "";

		return {
			name: nameEn,
			name_vn: nameVn,
			status: status,
			status_vn: statusVn,
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
			status_vn: "",
			days_left: 0,
			advice_en: e.message || String(e),
			advice_vn: e.message || String(e),
		};
	}
});

// listModels: debug helper
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

// scanReceipt: OCR a receipt image and return pantry items
exports.scanReceipt = onCall({ secrets: [GEMINI_API_KEY] }, async (request) => {
	try {
		const { image } = request.data;
		if (!image) throw new Error("Missing image");

		const prompt =
			`You are a grocery receipt OCR expert. Extract all food items from this receipt image and respond with ONLY a valid JSON array (no markdown, no explanation). Each item must have:
[
  {
    "name_en": "English name",
    "name_vn": "Vietnamese name",
    "quantity": <integer>,
    "unit": "kg or piece or item etc",
    "suggested_days": <integer days until expiry>,
    "type": "meat or seafood or vegetable or fruit or dairy or bread or other"
  }
]`;

		const resultText = await analyzeImageBase64(image, prompt, GEMINI_API_KEY.value());
		logger.info("Gemini OCR response:", resultText);

		const cleanText = resultText.replace(/```json|```/g, "").trim();
		const parsed = JSON.parse(cleanText);
		logger.info("Parsed OCR JSON:", parsed);

		return (Array.isArray(parsed) ? parsed : []).map((item) => ({
			name: item.name_en || "Unknown",
			name_vn: item.name_vn || "",
			quantity: item.quantity || 1,
			unit: item.unit || "item",
			suggested_days: item.suggested_days || 7,
			type: item.type || "other",
		}));
	} catch (e) {
		logger.error(e);
		return [];
	}
});
