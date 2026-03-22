import { Storage } from "./utils/storage.js";

const state = {
  route: { name: "login", params: {} },

  ui: { search: "" },

  auth: {
    token: Storage.get("deepsleep.token", ""),
    business_id: Storage.get("deepsleep.business_id", ""),
    email: Storage.get("deepsleep.email", ""),
    roles: Storage.get("deepsleep.roles", "").split(",").filter(Boolean),
  },

  account: {
    id: Number(Storage.get("deepsleep.account_id", "0") || 0) || 0,
    aws_account_id: Storage.get("deepsleep.aws_account_id", ""),
    name: Storage.get("deepsleep.account_name", "—"),
  },

  accounts: {
    list: [], // [{id, name, aws_account_id}]
    loaded: false,
  },

  plansCatalog: {
    supported: {},      // GET api/v1/plans
    planSchemas: {},    // GET api/v1/schemas/plans/{plan_type}
  },

  discovery: {
    lastQuery: null,
    resources: [],
    selectedKeys: new Set(),
    regionsCsv: "eu-west-1,eu-central-1,us-east-1",
    regionsList: [],
    resourceTypes: ["EKS_CLUSTER", "RDS_INSTANCE"],
  },

  active: {
    rowsByKey: new Map(),
    lastPollAt: null,
  },

  sleepPlans: {
    config: { sleep_plans: {} },
    names: [],
    loading: false,
  },

  policies: {
    list: [],
    selectedId: null,
    loading: false,
    editorWindows: [],
    editorSelectors: {
      EKS_CLUSTER: {},
      RDS_INSTANCE: {},
    },
  },
};

const listeners = new Set();

function getState() { return state; }

function setState(patch) {
  deepMerge(state, patch);
  listeners.forEach((fn) => fn(state));
}

function subscribe(fn) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

function deepMerge(target, patch) {
  for (const [k, v] of Object.entries(patch)) {
    if (v && typeof v === "object" && !Array.isArray(v) && !(v instanceof Set) && !(v instanceof Map)) {
      if (!target[k] || typeof target[k] !== "object") target[k] = {};
      deepMerge(target[k], v);
    } else {
      target[k] = v;
    }
  }
}

export const Store = { getState, setState, subscribe };
