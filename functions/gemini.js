// Gemini API wrapper for Node.js (server only) - v2


async function analyzeImageBase64(base64Image, prompt, apiKey) {
  if (!apiKey) {
    throw new Error("Gemini API key not set");
  }
  const cleanKey = apiKey.trim();
  console.log(`Gemini API key length: ${cleanKey.length}`);
  const GEMINI_API_URL =
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${cleanKey}`;
  const partialKey = cleanKey ? `${cleanKey.substring(0, 5)}...${cleanKey.substring(cleanKey.length - 5)}` : "MISSING";
  console.log(`Calling Gemini API [Key: ${partialKey}] URL:`, GEMINI_API_URL.replace(cleanKey, "REDACTED"));
  let mimeType = "image/jpeg";
  if (base64Image.startsWith("iVBORw0KGgo")) mimeType = "image/png";
  else if (base64Image.startsWith("UklGR")) mimeType = "image/webp";

  const body = {
    contents: [
      {
        parts: [
          { text: prompt },
          { inlineData: { mimeType: mimeType, data: base64Image } }
        ]
      },
    ],
  };
  console.log("Request body model structure: contents[0].parts.length =", body.contents[0].parts.length);
  const response = await fetch(GEMINI_API_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}));
    console.error("Gemini API detailed error:", JSON.stringify(errorData));
    throw new Error(`Gemini API error: ${response.status} ${response.statusText}`);
  }
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
