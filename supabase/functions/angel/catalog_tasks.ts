// Models may prepare a proposal. Only an explicit chat confirmation executes it.
export const catalogTaskTools = [{
  type: "function",
  function: {
    name: "prepare_catalog_change",
    description: "Prepare ONE owner-requested product selling-price or inventory change for confirmation. This does NOT execute it. Use the exact product name, SKU, barcode or ID; never guess among variants. price sets selling price; stock_set sets total stock; stock_adjust adds a signed amount to stock. Ask for missing values or an ambiguous product. Do not use for hypothetical questions, past actions, product deletion, costs, sales, or other tasks.",
    parameters: {
      type: "object", additionalProperties: false,
      properties: {
        product_query: { type: "string", description: "Exact product name, SKU, barcode or UUID from authorized data." },
        operation: { type: "string", enum: ["price", "stock_set", "stock_adjust"] },
        value: { type: "number", description: "Price or total stock for a set operation; signed delta for an adjustment." },
        reason: { type: "string", description: "Brief reason based only on the owner's request." },
      },
      required: ["product_query", "operation", "value", "reason"],
    },
  },
}];

export function confirmationKind(message: string): boolean | null {
  const text = message.trim().toLowerCase().replace(/[.!?]+$/, "").trim();
  if (["confirm", "yes", "yes confirm", "confirm change", "apply", "apply change", "yes do it", "go ahead"].includes(text)) return true;
  if (["cancel", "cancel change", "no", "no cancel", "don't apply", "do not apply"].includes(text)) return false;
  return null;
}

export function validateProposal(call: any) {
  if (call?.type !== "function" || call.function?.name !== "prepare_catalog_change") throw new Error("Unsupported task");
  const args = JSON.parse(call.function.arguments);
  if (!args || typeof args !== "object" || Array.isArray(args)
    || Object.keys(args).sort().join(",") !== "operation,product_query,reason,value"
    || !["price", "stock_set", "stock_adjust"].includes(args.operation)
    || typeof args.product_query !== "string" || !args.product_query.trim() || args.product_query.length > 200
    || typeof args.reason !== "string" || !args.reason.trim() || args.reason.length > 500
    || typeof args.value !== "number" || !Number.isFinite(args.value)) throw new Error("Invalid task proposal");
  return args;
}

export async function prepareCatalogTask(caller: any, business: string, conversation: string, message: string, call: any) {
  const args = validateProposal(call);
  const { data, error } = await caller.rpc("prepare_trexven_angel_catalog_action", {
    p_business_id: business, p_conversation_id: conversation, p_product_query: args.product_query.trim(),
    p_operation: args.operation, p_value: String(args.value), p_reason: args.reason.trim(), p_source_message: message,
  });
  if (error) throw error;
  return validateReceipt(data);
}

export async function resolveCatalogTask(caller: any, business: string, conversation: string, action: any, confirm: boolean) {
  if (!action || !/^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(action.id)) throw new Error("Invalid action receipt");
  const { data, error } = await caller.rpc("resolve_trexven_angel_catalog_action", {
    p_business_id: business, p_conversation_id: conversation, p_action_id: action.id, p_confirm: confirm,
  });
  if (error) throw error;
  return validateReceipt(data);
}

function validateReceipt(data: any) {
  if (!data || typeof data !== "object" || Array.isArray(data)
    || !["pending", "completed", "cancelled", "expired", "conflict", "not_found", "ambiguous", "unchanged"].includes(data.status)) {
    throw new Error("Missing task receipt");
  }
  if (["pending", "completed"].includes(data.status)
    && (typeof data.id !== "string" || !["price", "stock_set", "stock_adjust"].includes(data.operation)
      || typeof data.product_name !== "string" || data.after_value == null
      || !Number.isFinite(Number(data.after_value))
      || (data.status === "completed" && data.verified !== true))) throw new Error("Unverified task receipt");
  return data;
}

export function taskReply(action: any, currency: string) {
  if (action.status === "ambiguous" || action.status === "not_found") {
    const matches = (action.matches ?? []).map((p: any) => `${p.name}${p.sku ? ` (SKU: ${p.sku})` : ` (ID: ${p.id})`}`).join("; ");
    return `I haven't changed anything. ${action.status === "ambiguous" ? "More than one product matches." : "I couldn't find an exact product match."} ${matches ? `Possible products: ${matches}. ` : ""}Please give the exact product name, SKU or barcode.`;
  }
  if (action.status === "unchanged") return `${action.product_name} already has that value (${action.after_value}). No change was needed.`;
  if (action.status === "cancelled") return "Cancelled. No product values were changed by this task.";
  if (action.status === "expired") return "That proposal expired. No change was made. Please request the change again.";
  if (action.status === "conflict") return "The product changed since the proposal. I haven't applied this task. Please request it again so I can show the latest values.";
  const price = action.operation === "price";
  const display = (value: any) => value == null ? "unset" : price
    ? `${/naira|NGN|₦/i.test(currency) ? "₦" : `${currency} `}${Number(value).toLocaleString("en-NG", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
    : `${value} ${action.unit ?? "units"}`;
  const product = `${action.product_name}${action.sku ? ` (SKU: ${action.sku})` : ""}`;
  const change = `${price ? "selling price" : "stock"} for ${product}: ${display(action.before_value)} → ${display(action.after_value)}`;
  if (action.status === "pending") return `Proposed ${change}. Reason: ${action.reason}. Reply CONFIRM to apply, or CANCEL. This expires in 10 minutes. No change has been made yet.`;
  return action.replayed ? `This change was already applied: ${change}. I did not apply it twice.` : `Updated and verified ${change}.`;
}

export function honestReadOnlyReply(message: string, answer: string) {
  const changeRequest = /\b(change|update|set|increase|reduce|decrease|adjust|restock|add|remove|deduct)\b/i.test(message)
    && /\b(price|stock|inventory|quantity|units|pieces)\b/i.test(message);
  const unsupportedClaim = /\b(i(?:'ve| have|’ve)?\s+(?:successfully\s+)?(?:changed|updated|set|adjusted|added|removed|restocked)|(?:price|stock|inventory|quantity)\s+(?:has been|was|is now)\s+(?:changed|updated|set|adjusted))\b/i.test(answer);
  if (changeRequest || unsupportedClaim) return "I haven't changed anything. Please specify one product and the exact selling price, stock total, or quantity to add/remove so I can prepare a change for your confirmation.";
  return answer;
}

export function taskFailureReply(error: any) {
  const known = ["Insufficient stock for adjustment", "Countable units require whole quantities", "Invalid price or stock quantity", "Branch catalog mutation workflow is not activated"];
  const explanation = known.find(text => String(error?.message ?? "").includes(text));
  return `I couldn't apply or prepare that change. ${explanation ? `${explanation}. ` : ""}No new change was confirmed. Please check the product and requested value, then retry.`;
}
