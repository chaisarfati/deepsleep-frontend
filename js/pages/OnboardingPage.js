import { qs } from "../utils/dom.js";
import { toast } from "../utils/toast.js";
import * as Api from "../api/services.js";

function buildScript(data) {
  const deepsleepAccountId = data.deepsleep_account_id;
  const externalId = data.external_id;
  const roleName = data.role_name;
  const policyName = data.policy_name;

  return `# Variables
DEEPSLEEP_ACCOUNT_ID="${deepsleepAccountId}"
EXTERNAL_ID="${externalId}"
ROLE_NAME="${roleName}"
POLICY_NAME="${policyName}"

# 1. Creation of the Trust Policy
cat <<TRUST_POLICY_EOF > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::\${DEEPSLEEP_ACCOUNT_ID}:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "\${EXTERNAL_ID}"
        }
      }
    }
  ]
}
TRUST_POLICY_EOF

# 2. Creation of the Role
aws iam create-role \\
  --role-name $ROLE_NAME \\
  --assume-role-policy-document file://trust-policy.json \\
  --description "Role assumed by Deep Sleep SaaS for FinOps automation"

# 3. Creation of the Permissions Policy
cat <<PERMISSIONS_POLICY_EOF > permissions-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity",
        "eks:ListClusters",
        "eks:DescribeCluster",
        "eks:ListNodegroups",
        "eks:DescribeNodegroup",
        "eks:UpdateNodegroupConfig",
        "eks:CreateAccessEntry",
        "eks:DeleteAccessEntry",
        "eks:AssociateAccessPolicy",
        "eks:DisassociateAccessPolicy",
        "rds:DescribeDBInstances",
        "ec2:DescribeInstances",
        "ec2:DescribeSpotPriceHistory",
        "rds:StopDBInstance",
        "rds:StartDBInstance",
        "rds:ListTagsForResource",
        "pricing:DescribeServices",
        "pricing:GetAttributeValues",
        "pricing:GetProducts",
        "pricing:GetPriceListFileUrl",
        "autoscaling:DescribeAutoScalingGroups",
        "tag:GetResources",
        "cloudwatch:GetMetricStatistics"
      ],
      "Resource": "*"
    }
  ]
}
PERMISSIONS_POLICY_EOF

# 4. Creation of the Policy in AWS
POLICY_ARN=$(aws iam create-policy \\
  --policy-name $POLICY_NAME \\
  --policy-document file://permissions-policy.json \\
  --query 'Policy.Arn' --output text)

# 5. Attach Policy to Role
aws iam attach-role-policy \\
  --role-name $ROLE_NAME \\
  --policy-arn $POLICY_ARN

# 6. Cleanup
rm trust-policy.json permissions-policy.json

echo "✅ AWS configuration complete. Role created: \${ROLE_NAME}"
echo "👉 Retrieve your role ARN with:"
echo "aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text"`;
}

export async function OnboardingPage() {
  const page = qs("#ds-page");
  if (!page) return;

  page.innerHTML = `
    <div class="ds-panel">
      <div class="ds-panel__head">
        <div>
          <div class="ds-panel__title">Your business doesn't have any account attached</div>
          <div class="ds-panel__sub">Attach one now and start saving.</div>
        </div>
      </div>

      <div style="padding:0 20px 20px 20px;display:grid;gap:18px;">
        <div class="ds-badge ds-badge--violet-matte">Step 1 — Generate onboarding script</div>

        <div class="ds-row">
          <button class="ds-btn ds-btn--wake" id="ds-onboarding-load" type="button">Generate Script</button>
          <button class="ds-btn" id="ds-onboarding-copy" type="button">Copy Script</button>
        </div>

        <pre id="ds-onboarding-script" style="white-space:pre-wrap;overflow:auto;padding:16px;border:1px solid #e5e5e5;border-radius:16px;background:#fbfbfb;font-family:ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;font-size:12px;color:#3e3e3e;min-height:220px;"></pre>

        <div class="ds-badge ds-badge--violet-matte">Step 2 — Paste the resulting values</div>

        <div class="ds-row" style="align-items:flex-start;">
          <div class="ds-field" style="flex:1 1 240px;">
            <div class="ds-label">Account name</div>
            <input class="ds-input" id="ds-onboarding-account-name" placeholder="Production AWS" />
          </div>

          <div class="ds-field" style="flex:1 1 240px;">
            <div class="ds-label">AWS Account ID</div>
            <input class="ds-input" id="ds-onboarding-aws-account-id" placeholder="123456789012" />
          </div>
        </div>

        <div class="ds-field">
          <div class="ds-label">Role ARN</div>
          <input class="ds-input" id="ds-onboarding-role-arn" placeholder="arn:aws:iam::123456789012:role/deepsleep-control-plane-role" />
        </div>

        <div class="ds-field">
          <div class="ds-label">External ID</div>
          <input class="ds-input" id="ds-onboarding-external-id" placeholder="Auto-filled after Generate Script" />
        </div>

        <div class="ds-row">
          <button class="ds-btn ds-btn--wake" id="ds-onboarding-create-account" type="button">Attach Account</button>
        </div>

        <div class="ds-mono-muted" id="ds-onboarding-status">—</div>
      </div>
    </div>
  `;

  const scriptEl = qs("#ds-onboarding-script");
  const statusEl = qs("#ds-onboarding-status");

  let instructions = null;

  async function loadInstructions() {
    try {
      statusEl.textContent = "Generating onboarding instructions…";
      instructions = await Api.getOnboardingInstructions();
      const script = buildScript(instructions);
      scriptEl.textContent = script;
      qs("#ds-onboarding-external-id").value = instructions.external_id || "";
      statusEl.textContent = "Instructions ready.";
    } catch (e) {
      statusEl.textContent = "Failed.";
      toast("Onboarding", e.message || "Unable to load onboarding instructions");
    }
  }

  qs("#ds-onboarding-load").addEventListener("click", loadInstructions);

  qs("#ds-onboarding-copy").addEventListener("click", async () => {
    try {
      const text = scriptEl.textContent || "";
      if (!text.trim()) throw new Error("Generate the script first.");
      await navigator.clipboard.writeText(text);
      toast("Onboarding", "Script copied to clipboard.");
    } catch (e) {
      toast("Onboarding", e.message || "Copy failed");
    }
  });

  qs("#ds-onboarding-create-account").addEventListener("click", async () => {
    try {
      const payload = {
        name: qs("#ds-onboarding-account-name").value.trim(),
        aws_account_id: qs("#ds-onboarding-aws-account-id").value.trim(),
        role_arn: qs("#ds-onboarding-role-arn").value.trim(),
        external_id: qs("#ds-onboarding-external-id").value.trim() || null,
      };

      if (!payload.name || !payload.aws_account_id || !payload.role_arn) {
        throw new Error("Missing account name / aws_account_id / role_arn");
      }

      statusEl.textContent = "Attaching account…";
      await Api.createAccount(payload);
      statusEl.textContent = "Account attached.";
      toast("Onboarding", "Account attached successfully.");

      window.location.hash = "#/discovery";
      window.dispatchEvent(new Event("hashchange"));
      window.location.reload();
    } catch (e) {
      statusEl.textContent = "Attach failed.";
      toast("Onboarding", e.message || "Failed to attach account");
    }
  });

  await loadInstructions();
}
