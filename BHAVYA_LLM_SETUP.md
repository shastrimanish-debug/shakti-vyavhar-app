Bhavya v2.0 adds an optional OpenAI-compatible LLM layer. The model only converts natural speech into an allow-listed intent; it has no database access.

Recommended production setup: use an HTTPS backend/proxy and keep the provider API key on that server. Configure Codemagic secrets BHAVYA_LLM_URL, BHAVYA_LLM_API_KEY and BHAVYA_LLM_MODEL. If these values are absent, the offline parser remains active.
