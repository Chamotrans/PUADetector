# LLM Relay Contract

PUA Detector supports an optional Pro LLM deep scan for manually submitted text. The live microphone flow and baseline classifier stay on-device.

Do not point the app at Amazing Tutor's `/v1/generate-questions` endpoint. That route is tied to question-generation schema and Amazing Tutor quota. PUA Detector should use a PUA-specific relay route such as `/v1/pua-analyze`.

## Request

`POST /v1/pua-analyze`

Headers:

```http
Content-Type: application/json
Authorization: Bearer <Amazing Tutor account token>
X-Relay-Service-Key: <server-to-server key>
```

Use either `Authorization` for user-account mode or `X-Relay-Service-Key` for trusted backend mode. Keep the DeepSeek API key in relay environment variables only.

Body:

```json
{
  "task": "puaDeepScan",
  "locale": "zh-HK",
  "conversation": "你太敏感啦，除咗我冇人會要你",
  "localClassifier": {
    "score": 92,
    "categories": ["gaslighting", "ownership"],
    "signals": [
      {
        "category": "gaslighting",
        "phrase": "你太敏感",
        "similarity": 1,
        "weight": 22
      }
    ]
  },
  "responseFormat": "json",
  "schemaVersion": 1
}
```

`conversation` is redacted in-app before submission. The current redactor masks email addresses, phone numbers, and account-like identifiers.

## Response

The app accepts either a direct analysis object:

```json
{
  "severity": "danger",
  "categories": ["gaslighting", "ownership"],
  "reasons": [
    "The text dismisses the user's perception and frames dependence as proof of care."
  ],
  "suggestedReplies": [
    "我需要按自己的感受和節奏決定，不接受被否定或控制。"
  ]
}
```

Or a wrapped relay response:

```json
{
  "analysis": {
    "severity": "danger",
    "categories": ["gaslighting", "ownership"],
    "reasons": ["..."],
    "suggestedReplies": ["..."]
  },
  "provider": "deepseek",
  "model": "deepseek-chat",
  "quota": {
    "puaDeepScansRemaining": 9
  }
}
```

Valid `severity` values match the app risk levels: `low`, `watch`, `warning`, and `danger`.

Valid `categories` are the raw `PUAClassifier.Category` values used by the app, including `gaslighting`, `negging`, `guilt`, `isolation`, `ownership`, `threat`, `financial`, and `boundary`.

## Prompt Guidance

Ask the model to return JSON only. The analysis should identify manipulation patterns in the submitted conversation, cite concise reasons, and suggest boundary-setting replies in Traditional Chinese or Cantonese-friendly wording when appropriate.

The response must not present itself as a diagnosis, legal conclusion, or factual verdict. PUA Detector displays the LLM result as a language-pattern reference only.
