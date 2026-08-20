const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const GROQ_API_URL =
    "https://api.groq.com/openai/v1/chat/completions";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  try {
    const body = await req.json();

    if (!body || typeof body.query !== "string") {
      return new Response(
        JSON.stringify({
          success: false,
          error: "A query is required.",
        }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    const query = body.query.trim();

    if (query.length === 0) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Query cannot be empty.",
        }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    if (query.length > 5000) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Message is too long.",
        }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    const groqApiKey = Deno.env.get("GROQ_API_KEY");

    if (!groqApiKey) {
      throw new Error("GROQ_API_KEY is not configured.");
    }

    const groqResponse = await fetch(
      GROQ_API_URL,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${groqApiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "llama-3.3-70b-versatile",
          messages: [
            {
              role: "system",
              content: `
You are Angel, the intelligent business assistant inside TREXVEN.

TREXVEN is a professional business management and intelligence platform.

Your role is to help business owners understand and manage their business.

You will eventually work with information from:

- Inventory
- Products
- Stock quantities
- Sales
- Revenue
- Expenses
- Employees
- Employee activity
- Security cameras
- Cash activity
- Shelf activity
- Stock movement
- Business activity
- Camera events
- Security events

IMPORTANT BEHAVIOR:

1. Your name is Angel.

2. Speak naturally, professionally and clearly.

3. Keep answers concise unless the user asks for detail.

4. Never invent business numbers.

5. Never pretend that you have access to a camera when you don't.

6. Never claim that an employee stole something unless the available evidence actually supports that conclusion.

7. When discussing camera information, distinguish between:
   - What was observed
   - What was detected
   - What may have happened
   - What is confirmed

8. When TREXVEN eventually provides business data, use that data rather than guessing.

9. Help the owner understand business performance, inventory, finances, employees and unusual activity.

10. If required information is unavailable, clearly tell the owner what information is missing.

11. Do not describe yourself as a generic chatbot.

12. You are Angel, the intelligence assistant built into TREXVEN.

Your goal is to help the business owner make better decisions.
              `,
            },
            {
              role: "user",
              content: query,
            },
          ],
          temperature: 0.3,
          max_tokens: 800,
        }),
      },
    );

    if (!groqResponse.ok) {
      const errorText = await groqResponse.text();

      console.error(
        "Groq API error:",
        groqResponse.status,
        errorText,
      );

      throw new Error(
        `Groq request failed with status ${groqResponse.status}`,
      );
    }

    const result = await groqResponse.json();

    const answer =
        result?.choices?.[0]?.message?.content;

    if (!answer) {
      throw new Error("Groq returned an empty response.");
    }

    return new Response(
      JSON.stringify({
        success: true,
        answer: answer,
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  } catch (error) {
    console.error("Angel error:", error);

    return new Response(
      JSON.stringify({
        success: false,
        error:
            "Angel could not connect to the intelligence service.",
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  }
});