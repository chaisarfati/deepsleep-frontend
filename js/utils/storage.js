export const Storage = {
  get(key, fallback = "") {
    const v = localStorage.getItem(key);
    return v === null ? fallback : v;
  },
  set(key, value) {
    localStorage.setItem(key, String(value ?? ""));
  },
  del(key) {
    localStorage.removeItem(key);
  },
};
