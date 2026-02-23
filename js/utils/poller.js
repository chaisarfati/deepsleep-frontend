export function createPoller({ intervalMs, tick, guard = () => true, leadingDelayMs = 700 }) {
  let timer = null;

  async function safeTick() {
    if (!guard()) return;
    try { await tick(); } catch { /* caller may handle */ }
  }

  function start() {
    stop();
    timer = setInterval(safeTick, intervalMs);
    setTimeout(safeTick, leadingDelayMs);
  }

  function stop() {
    if (timer) clearInterval(timer);
    timer = null;
  }

  return { start, stop };
}
