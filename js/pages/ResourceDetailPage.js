/**
 * ResourceDetailPage.js
 * Route: #/resource?type=EKS_CLUSTER&name=my-cluster&region=eu-west-1
 *
 * Calls GET /accounts/{id}/resource-states/{resource_name}?resource_type=...&region=...
 */
import { Store } from "../store.js";
import { toast } from "../utils/toast.js";
import { qs, escapeHtml as h } from "../utils/dom.js";
import { fmtTime } from "../utils/time.js";
import * as Api from "../api/services.js";

function resourceChipClass(type) {
  if (type === "EKS_CLUSTER")  return "ds-resource-chip ds-resource-chip--eks";
  if (type === "RDS_INSTANCE") return "ds-resource-chip ds-resource-chip--rds";
  if (type === "EC2_INSTANCE") return "ds-resource-chip ds-resource-chip--ec2";
  return "ds-resource-chip";
}

function resourceTypeShort(type) {
  return type === "EKS_CLUSTER" ? "EKS" : type === "RDS_INSTANCE" ? "RDS" : type === "EC2_INSTANCE" ? "EC2" : type;
}

function infoRow(label, value, mono = false) {
  if (value === null || value === undefined || value === "") return "";
  const display = mono
    ? `<span class="ds-mono" style="font-size:12px;">${h(String(value))}</span>`
    : `<span style="font-size:13px;color:var(--fg-strong);">${h(String(value))}</span>`;
  return `
    <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:16px;padding:10px 0;border-bottom:1px solid var(--stone-100);">
      <span style="font-size:12px;font-weight:500;color:var(--fg-faint);flex-shrink:0;min-width:160px;">${h(label)}</span>
      ${display}
    </div>`;
}

function renderEKSDetail(data) {
  const nodegroups = data.nodegroups || [];
  return `
    <div class="ds-panel" style="margin-bottom:12px;">
      <div class="ds-panel__head">
        <div class="ds-panel__title">Cluster</div>
      </div>
      <div class="ds-panel__body" style="padding-top:0;">
        ${infoRow("Kubernetes version", data.version, true)}
        ${infoRow("Status", data.status, true)}
        ${infoRow("Endpoint", data.endpoint, true)}
      </div>
    </div>

    ${nodegroups.length ? `
    <div class="ds-panel">
      <div class="ds-panel__head">
        <div class="ds-panel__title">Node Groups <span class="ds-badge" style="margin-left:6px;">${nodegroups.length}</span></div>
      </div>
      <div class="ds-panel__body" style="padding-top:0;">
        <div class="ds-tablewrap">
          <table class="ds-table">
            <thead><tr>
              <th>Name</th><th>Status</th><th>Min</th><th>Desired</th><th>Max</th><th>Instance types</th>
            </tr></thead>
            <tbody>
              ${nodegroups.map(ng => `<tr>
                <td><span class="ds-mono" style="font-size:12px;">${h(ng.name)}</span></td>
                <td><span class="ds-badge ${ng.status === "ACTIVE" ? "ds-badge--success" : ""}">${h(ng.status || "—")}</span></td>
                <td><span class="ds-mono">${ng.min_size ?? "—"}</span></td>
                <td><span class="ds-mono" style="font-weight:600;">${ng.desired_size ?? "—"}</span></td>
                <td><span class="ds-mono">${ng.max_size ?? "—"}</span></td>
                <td><span class="ds-mono" style="font-size:11px;">${h((ng.instance_types || []).join(", ") || "—")}</span></td>
              </tr>`).join("")}
            </tbody>
          </table>
        </div>
      </div>
    </div>` : ""}

    ${data.tags && Object.keys(data.tags).length ? `
    <div class="ds-panel">
      <div class="ds-panel__head"><div class="ds-panel__title">Tags</div></div>
      <div class="ds-panel__body" style="padding-top:0;">
        <div style="display:flex;flex-wrap:wrap;gap:6px;">
          ${Object.entries(data.tags).map(([k, v]) =>
            `<span class="ds-chip"><span style="color:var(--fg-faint)">${h(k)}</span><span style="margin:0 4px;color:var(--fg-faint)">=</span>${h(v)}</span>`
          ).join("")}
        </div>
      </div>
    </div>` : ""}
  `;
}

function renderRDSDetail(data) {
  return `
    <div class="ds-panel" style="margin-bottom:12px;">
      <div class="ds-panel__head"><div class="ds-panel__title">Instance</div></div>
      <div class="ds-panel__body" style="padding-top:0;">
        ${infoRow("Status", data.status, true)}
        ${infoRow("Engine", data.engine, true)}
        ${infoRow("Class", data.class, true)}
        ${infoRow("Endpoint", data.endpoint, true)}
        ${infoRow("Port", data.port)}
        ${infoRow("Storage", data.allocated_storage ? `${data.allocated_storage} GiB (${data.storage_type})` : null)}
        ${infoRow("Multi-AZ", data.multi_az !== undefined ? String(data.multi_az) : null)}
        ${infoRow("Publicly accessible", data.publicly_accessible !== undefined ? String(data.publicly_accessible) : null)}
      </div>
    </div>`;
}

function renderEC2Detail(data) {
  return `
    <div class="ds-panel" style="margin-bottom:12px;">
      <div class="ds-panel__head"><div class="ds-panel__title">Instance</div></div>
      <div class="ds-panel__body" style="padding-top:0;">
        ${infoRow("Status", data.status, true)}
        ${infoRow("Instance type", data.instance_type, true)}
        ${infoRow("Platform", data.platform, true)}
        ${infoRow("Public IP", data.public_ip, true)}
        ${infoRow("Private IP", data.private_ip, true)}
        ${infoRow("VPC", data.vpc_id, true)}
        ${infoRow("Subnet", data.subnet_id, true)}
        ${infoRow("AZ", data.availability_zone, true)}
        ${infoRow("AMI", data.image_id, true)}
        ${infoRow("Key pair", data.key_name, true)}
      </div>
    </div>

    ${data.tags && Object.keys(data.tags).length ? `
    <div class="ds-panel">
      <div class="ds-panel__head"><div class="ds-panel__title">Tags</div></div>
      <div class="ds-panel__body" style="padding-top:0;">
        <div style="display:flex;flex-wrap:wrap;gap:6px;">
          ${Object.entries(data.tags).map(([k, v]) =>
            `<span class="ds-chip"><span style="color:var(--fg-faint)">${h(k)}</span><span style="margin:0 4px;color:var(--fg-faint)">=</span>${h(v)}</span>`
          ).join("")}
        </div>
      </div>
    </div>` : ""}
  `;
}

function renderDetail(data) {
  const type = data.resource_type;
  if (type === "EKS_CLUSTER")  return renderEKSDetail(data);
  if (type === "RDS_INSTANCE") return renderRDSDetail(data);
  if (type === "EC2_INSTANCE") return renderEC2Detail(data);
  return `<pre class="ds-code">${JSON.stringify(data, null, 2)}</pre>`;
}

export async function ResourceDetailPage(route) {
  const page = qs("#ds-page");
  if (!page) return;

  const s = Store.getState();
  if (!s.auth.token) { toast("Auth", "Please login."); location.hash = "#/login"; return; }

  const params = route?.params || {};
  const resourceType = params.type || "";
  const resourceName = params.name || "";
  const region       = params.region || "";

  if (!resourceType || !resourceName || !region) {
    page.innerHTML = `<div class="ds-empty">
      <div class="ds-empty__title">Missing parameters</div>
      <div class="ds-empty__sub">Navigate to this page via a resource link.</div>
      <button class="ds-btn" style="margin-top:12px;" onclick="history.back()">← Back</button>
    </div>`;
    return;
  }

  page.innerHTML = `
    <div class="ds-page-header" style="margin-bottom:20px;">
      <div style="display:flex;align-items:center;gap:12px;flex-wrap:wrap;">
        <button class="ds-btn ds-btn--ghost" onclick="history.back()" style="flex-shrink:0;">
          <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.8">
            <path d="M9 2L4 7l5 5"/>
          </svg>
          Back
        </button>
        <span class="${resourceChipClass(resourceType)}" style="font-size:12px;">${resourceTypeShort(resourceType)}</span>
        <div>
          <div class="ds-page-title">${h(resourceName)}</div>
          <div class="ds-page-sub">${h(region)}</div>
        </div>
      </div>
    </div>

    <div id="ds-detail-body">
      <div class="ds-loading"><div class="ds-spinner"></div>Fetching resource details from AWS…</div>
    </div>
  `;

  const body = qs("#ds-detail-body");
  const accountId = s.account.id;

  try {
    const data = await Api.getResourceDetail(accountId, resourceType, resourceName, region);
    body.innerHTML = renderDetail(data);
  } catch (e) {
    body.innerHTML = `<div class="ds-empty">
      <svg class="ds-empty__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
        <circle cx="12" cy="12" r="9"/><path d="M12 7v5M12 16h.01"/>
      </svg>
      <div class="ds-empty__title">Could not load details</div>
      <div class="ds-empty__sub">${h(e.message || "AWS API error")}</div>
    </div>`;
    toast("Resource Detail", e.message || "Failed to load.");
  }
}
