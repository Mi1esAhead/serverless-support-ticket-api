"use strict";
// Must match: terraform -chdir=terraform output -raw api_url
const API_BASE = "https://tickets-api.m1portfolio.com";
const el = id => document.getElementById(id);
let online = false;
let busy = false;
const samples = [
  "Synthetic demo: VPN disconnects every ten minutes on a test workstation.",
  "Synthetic demo: A lab printer is offline after a network restart.",
  "Synthetic demo: The training portal returns an error during test sign-in.",
  "Synthetic demo: A sandbox application responds slowly to sample requests."
];
function controls() {
  el("create-fields").disabled = busy || !online;
  el("lookup-fields").disabled = busy || !online;
  el("check").disabled = busy;
}
function availability(value, message) {
  online = value;
  el("status").textContent = value ? "ONLINE" : "OFFLINE / UNREACHABLE";
  el("availability").textContent = message;
  controls();
}
function generate() {
  el("description").value = samples[Math.floor(Math.random() * samples.length)];
}
async function request(path, options = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000);
  try {
    const response = await fetch(API_BASE + path, {
      ...options, signal: controller.signal, cache: "no-store", credentials: "omit"
    });
    const raw = await response.text();
    let data;
    try { data = JSON.parse(raw); }
    catch { data = { message: raw || "Empty response" }; }
    if (!response.ok) {
      const error = new Error(`HTTP ${response.status}`);
      error.status = response.status;
      error.data = data;
      throw error;
    }
    return data;
  } finally { clearTimeout(timeout); }
}
function showError(error, creating = false) {
  const detail = error.status ? `${error.message}\n${JSON.stringify(error.data, null, 2)}` :
    (error.name === "AbortError" ? "Request timed out." : "Request could not reach the API. Check network, CORS, and CSP.");
  el("result").textContent = detail + (creating ? "\nIf the response was lost, the ticket may still have been saved. The demo does not automatically retry POST requests." : "");
  if (!error.status || error.status >= 500) {
    availability(false, "API unavailable or request failed. Use Check API status to retry; a failure does not prove the demo was intentionally switched off.");
  } else if (error.status === 429) {
    el("availability").textContent = "Rate limited. Wait before trying again.";
  }
}
async function check() {
  if (busy) return;
  busy = true; controls();
  el("status").textContent = "CHECKING";
  try {
    const data = await request("/health");
    if (data.status !== "ok") throw new Error("Unexpected health response");
    availability(true, "Application is responding. Create and retrieve a ticket to verify storage.");
  } catch (error) {
    availability(false, "Demo is off or unreachable. You can check again manually.");
    showError(error);
  } finally { busy = false; controls(); }
}
el("check").addEventListener("click", check);
el("generate").addEventListener("click", generate);
el("create-form").addEventListener("submit", async event => {
  event.preventDefault();
  if (busy || !online) return;
  busy = true; controls();
  try {
    const data = await request("/tickets", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ description: el("description").value, priority: el("priority").value })
    });
    el("result").textContent = JSON.stringify(data, null, 2);
    el("ticket-id").value = data.id;
  } catch (error) { showError(error, true); }
  finally { busy = false; controls(); }
});
el("lookup-form").addEventListener("submit", async event => {
  event.preventDefault();
  if (busy || !online) return;
  const id = el("ticket-id").value.trim();
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) {
    el("result").textContent = "Enter a valid ticket UUID.";
    return;
  }
  busy = true; controls();
  try { el("result").textContent = JSON.stringify(await request("/tickets/" + encodeURIComponent(id)), null, 2); }
  catch (error) { showError(error); }
  finally { busy = false; controls(); }
});
generate();
check();