/**
 * DeepSleep API Services — v4 2026
 * Supports: resource-states (DB-only), resource-states/verify (async),
 * resource-pricing-batch (deduplicated batch)
 */

import { request } from "./client.js";

const V1 = "/api/v1";

/* ── Auth ────────────────────────────────────────────────── */
export const login   = (payload) => request("/auth/login",   { method: "POST", body: payload });
export const refresh = (payload) => request("/auth/refresh", { method: "POST", body: payload });

/* ── Accounts ────────────────────────────────────────────── */
export const listAccounts  = ()        => request("/accounts");
export const createAccount = (payload) => request("/accounts", { method: "POST", body: payload });

/* ── Catalog ─────────────────────────────────────────────── */
export const getOnboardingInstructions = () =>
  request(`${V1}/accounts/onboarding-instructions`);
export const getSupportedPlans = () => request(`${V1}/plans`);
export const getStepSchema = (stepType) =>
  request(`${V1}/schemas/steps/${encodeURIComponent(stepType)}`);
export const getPlanSchema = (planType) =>
  request(`${V1}/schemas/plans/${encodeURIComponent(planType)}`);

/* ── Account Config ──────────────────────────────────────── */
export const getAccountConfig = (accountId) =>
  request(`/accounts/${accountId}/config`);
export const putAccountConfig = (accountId, body) =>
  request(`/accounts/${accountId}/config`, { method: "PUT", body });

/* ── Discovery ───────────────────────────────────────────── */
export const searchResources = (accountId, body) =>
  request(`/accounts/${accountId}/resources/search`, { method: "POST", body });

/* ── Batch register ──────────────────────────────────────── */
export const batchRegisterResources = (accountId, body) =>
  request(`/accounts/${accountId}/resources/batch-register`, { method: "POST", body });

/* ── Single register / unregister ───────────────────────── */
export const registerResource = (accountId, body) =>
  request(`/accounts/${accountId}/resources/register`, { method: "POST", body });
export const unregisterResource = (accountId, body) =>
  request(`/accounts/${accountId}/resources/unregister`, { method: "POST", body });

/* ── Sleep / Wake ────────────────────────────────────────── */
export const sleepResource = (accountId, body) =>
  request(`/accounts/${accountId}/resources/sleep`, { method: "POST", body });
export const wakeResource = (accountId, body) =>
  request(`/accounts/${accountId}/resources/wake`, { method: "POST", body });

/* ── Resource states — DB only, ~instant ─────────────────── */
export const listResourceStates = (accountId, resourceType = null) =>
  request(`/accounts/${accountId}/resource-states`, {
    query: resourceType ? { resource_type: resourceType } : {},
  });

/**
 * Fire-and-forget existence check.
 * Send the resource list received from listResourceStates.
 * Returns which resources are newly DROPPED.
 * @param {number} accountId
 * @param {Array<{resource_type, resource_name, region}>} resources
 */
export const verifyResourceExistence = (accountId, resources) =>
  request(`/accounts/${accountId}/resource-states/verify`, {
    method: "POST",
    body: { resources },
  });

/* ── Batch pricing — deduplicated, single round-trip ─────── */
/**
 * Price a batch of resources in one call.
 * @param {number} accountId
 * @param {Array<{resource_type, resource_name, region, observed_state}>} resources
 * @returns {{ pricing: Record<string, {cost: number|null, savings: number|null}> }}
 */
export const getResourcePricingBatch = (accountId, resources) =>
  request(`/accounts/${accountId}/resource-pricing-batch`, {
    method: "POST",
    body: { resources },
  });

/* ── Aggregated savings window ───────────────────────────── */
export const getAccountPriceSavings = (accountId, body) =>
  request(`/accounts/${accountId}/price-savings`, { method: "POST", body });

/* ── Time Policies ───────────────────────────────────────── */
export const listPolicies  = (accountId)                   => request(`/accounts/${accountId}/time-policies`);
export const getPolicy     = (accountId, policyId)         => request(`/accounts/${accountId}/time-policies/${policyId}`);
export const createPolicy  = (accountId, body)             => request(`/accounts/${accountId}/time-policies`, { method: "POST", body });
export const updatePolicy  = (accountId, policyId, body)   => request(`/accounts/${accountId}/time-policies/${policyId}`, { method: "PUT", body });
export const deletePolicy  = (accountId, policyId)         => request(`/accounts/${accountId}/time-policies/${policyId}`, { method: "DELETE" });
export const enablePolicy  = (accountId, policyId)         => request(`/accounts/${accountId}/time-policies/${policyId}/enable`, { method: "POST" });
export const disablePolicy = (accountId, policyId)         => request(`/accounts/${accountId}/time-policies/${policyId}/disable`, { method: "POST" });
export const runPolicyNow  = (accountId, policyId, action) =>
  request(`/accounts/${accountId}/time-policies/${policyId}/run-now`, { method: "POST", body: { action } });

/* ── History ─────────────────────────────────────────────── */
export const listRuns = (accountId, params = {}) =>
  request(`/accounts/${accountId}/runs`, { query: params });

/* ── Users ───────────────────────────────────────────────── */
export const listUsers          = ()             => request("/users");
export const getUser            = (userId)       => request(`/users/${userId}`);
export const createUser         = (body)         => request("/users", { method: "POST", body });
export const updateUserRoles    = (userId, body) => request(`/users/${userId}/roles`,    { method: "PUT", body });
export const updateUserAccounts = (userId, body) => request(`/users/${userId}/accounts`, { method: "PUT", body });
export const deleteUser         = (userId)       => request(`/users/${userId}`, { method: "DELETE" });
