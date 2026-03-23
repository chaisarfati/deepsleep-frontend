import { request } from "./client.js";

/* Auth */
export const login = (payload) => request("/auth/login", { method: "POST", body: payload });
export const refresh = (payload) => request("/auth/refresh", { method: "POST", body: payload });

/* Accounts */
export const listAccounts = () => request("/accounts");

/* Plan catalog / schemas */
export const getSupportedPlans = () => request("/plans");
export const getStepSchema = (stepType) => request(`/schemas/steps/${encodeURIComponent(stepType)}`);
export const getPlanSchema = (planType) => request(`/schemas/plans/${encodeURIComponent(planType)}`);

/* Account Config (Sleep Plans) */
export const getAccountConfig = (accountId) =>
  request(`/accounts/${accountId}/config`);

export const putAccountConfig = (accountId, body) =>
  request(`/accounts/${accountId}/config`, { method: "PUT", body });

/* Resources */
export const searchResources = (accountId, body) =>
  request(`/accounts/${accountId}/resources/search`, { method: "POST", body });

export const batchRegister = (accountId, body) =>
  request(`/accounts/${accountId}/resources/batch-register`, { method: "POST", body });

/* EKS states + orchestration */
export const listClusterStates = (accountId) =>
  request(`/accounts/${accountId}/cluster-states`);

export const sleepEKS = (accountId, clusterName, region, planName) =>
  request(`/accounts/${accountId}/eks-clusters/${encodeURIComponent(clusterName)}/sleep`, {
    method: "POST",
    query: { region, plan_name: planName || "dev" },
  });

export const wakeEKS = (accountId, clusterName, region) =>
  request(`/accounts/${accountId}/eks-clusters/${encodeURIComponent(clusterName)}/wake`, {
    method: "POST",
    query: { region },
  });

export const unregisterEKS = (accountId, clusterName, region) =>
  request(`/accounts/${accountId}/eks-clusters/${encodeURIComponent(clusterName)}/register`, {
    method: "DELETE",
    query: { region },
  });

/* EKS price / savings */
export const getEksClusterPrice = (accountId, clusterName, region) =>
  request(`/accounts/${accountId}/eks-clusters/${encodeURIComponent(clusterName)}/price`, {
    method: "GET",
    query: { region },
  });

export const getEksClusterPriceSavings = (accountId, clusterName, region) =>
  request(`/accounts/${accountId}/eks-clusters/${encodeURIComponent(clusterName)}/price-savings`, {
    method: "GET",
    query: { region },
  });

/* RDS states + orchestration */
export const listRdsStates = (accountId) =>
  request(`/accounts/${accountId}/rds-instance-states`);

export const sleepRDS = (accountId, dbInstanceId, region, planName) =>
  request(`/accounts/${accountId}/rds-instances/${encodeURIComponent(dbInstanceId)}/sleep`, {
    method: "POST",
    query: { region, plan_name: planName || "rds_dev" },
  });

export const wakeRDS = (accountId, dbInstanceId, region) =>
  request(`/accounts/${accountId}/rds-instances/${encodeURIComponent(dbInstanceId)}/wake`, {
    method: "POST",
    query: { region },
  });

export const unregisterRDS = (accountId, dbInstanceId, region) =>
  request(`/accounts/${accountId}/rds-instances/${encodeURIComponent(dbInstanceId)}/register`, {
    method: "DELETE",
    query: { region },
  });

/* RDS price / savings */
export const getRdsInstancePrice = (accountId, dbInstanceId, region) =>
  request(`/accounts/${accountId}/rds-instances/${encodeURIComponent(dbInstanceId)}/price`, {
    method: "GET",
    query: { region },
  });

export const getRdsInstancePriceSavings = (accountId, dbInstanceId, region) =>
  request(`/accounts/${accountId}/rds-instances/${encodeURIComponent(dbInstanceId)}/price-savings`, {
    method: "GET",
    query: { region },
  });

/* Account aggregated savings */
export const getAccountPriceSavings = (accountId, body) =>
  request(`/accounts/${accountId}/price-savings`, {
    method: "POST",
    body,
  });

/* Time policies */
export const listPolicies = (accountId) =>
  request(`/accounts/${accountId}/time-policies`);

export const getPolicy = (accountId, policyId) =>
  request(`/accounts/${accountId}/time-policies/${policyId}`);

export const createPolicy = (accountId, body) =>
  request(`/accounts/${accountId}/time-policies`, { method: "POST", body });

export const updatePolicy = (accountId, policyId, body) =>
  request(`/accounts/${accountId}/time-policies/${policyId}`, { method: "PUT", body });

export const deletePolicy = (accountId, policyId) =>
  request(`/accounts/${accountId}/time-policies/${policyId}`, { method: "DELETE" });

export const runPolicyNow = (accountId, policyId, action) =>
  request(`/accounts/${accountId}/time-policies/${policyId}/run-now`, { method: "POST", body: { action } });

/* History */
export const listRuns = (accountId, params = {}) =>
  request(`/accounts/${accountId}/runs`, {
    method: "GET",
    query: params,
  });

/* Users */
export const listUsers = () => request("/users");
export const getUser = (userId) => request(`/users/${userId}`);
export const createUser = (body) => request("/users", { method: "POST", body });
export const updateUserRoles = (userId, body) => request(`/users/${userId}/roles`, { method: "PUT", body });
export const updateUserAccounts = (userId, body) => request(`/users/${userId}/accounts`, { method: "PUT", body });
export const deleteUser = (userId) => request(`/users/${userId}`, { method: "DELETE" });
