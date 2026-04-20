/**
 * DeepSleep API Services — v3 2026
 * Aligned with the standardized backend API after migration.
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

/* ── Account Config (Sleep Plans) ───────────────────────── */
export const getAccountConfig = (accountId) =>
  request(`/accounts/${accountId}/config`);

export const putAccountConfig = (accountId, body) =>
  request(`/accounts/${accountId}/config`, { method: "PUT", body });

/* ── Resource discovery ──────────────────────────────────── */
export const searchResources = (accountId, body) =>
  request(`/accounts/${accountId}/resources/search`, { method: "POST", body });

/* ── Batch register / unregister ─────────────────────────── */
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

/* ── Resource states (unified — replaces cluster-states, rds-instance-states, ec2-instance-states) */
export const listResourceStates = (accountId, resourceType = null) =>
  request(`/accounts/${accountId}/resource-states`, {
    query: resourceType ? { resource_type: resourceType } : {},
  });

/* ── Costs ───────────────────────────────────────────────── */

/**
 * Hourly price for a resource (call for RUNNING resources).
 */
export const getResourcePrice = (accountId, resourceType, resourceName, region) =>
  request(`/accounts/${accountId}/resource-price`, {
    query: { resource_type: resourceType, resource_name: resourceName, region },
  });

/**
 * Current hourly savings rate (call ONLY when observed_state === "SLEEPING").
 */
export const getResourceSavings = (accountId, resourceType, resourceName, region) =>
  request(`/accounts/${accountId}/resource-savings`, {
    query: { resource_type: resourceType, resource_name: resourceName, region },
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
export const runPolicyNow  = (accountId, policyId, action) => request(`/accounts/${accountId}/time-policies/${policyId}/run-now`, { method: "POST", body: { action } });

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
