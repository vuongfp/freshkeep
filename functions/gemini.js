// Gemini API wrapper for Node.js (server only)
const fetch = require("node-fetch");



async function analyzeImageBase64(base64Image, prompt, apiKey) {
  if (!apiKey) {
    throw new Error("Gemini API key not set");
  }
  const GEMINI_API_URL =
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=" +
    apiKey;
  const body = {
    contents: [
      { parts: [{ text: prompt }] },
      { parts: [{ inlineData: { mimeType: "image/jpeg", data: base64Image } }] },
    ],
  };
  const response = await fetch(GEMINI_API_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!response.ok) throw new Error("Gemini API error: " + response.statusText);
  const data = await response.json();
  return (
    (data.candidates &&
      data.candidates[0] &&
      data.candidates[0].content &&
      data.candidates[0].content.parts &&
      data.candidates[0].content.parts[0] &&
      data.candidates[0].content.parts[0].text) || null
  );
}

module.exports = { analyzeImageBase64 };
