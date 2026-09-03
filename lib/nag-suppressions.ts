/**
 * cdk-nag suppression helper. Use instead of `NagSuppressions` directly: it refuses any
 * waiver without a real (>=15 char, non-placeholder) justification. Pair with the app-entry
 * Aspect `Aspects.of(app).add(new AwsSolutionsChecks())` (error-level findings fail synth).
 */
import { NagSuppressions } from 'cdk-nag';
import type { IConstruct } from 'constructs';

export interface Suppression {
  /** cdk-nag rule id, e.g. 'AwsSolutions-IAM5'. */
  readonly id: string;
  /** Why this violation is acceptable. MUST be a real justification. */
  readonly reason: string;
  /** Optional: limit the suppression to specific findings within the rule. */
  readonly appliesTo?: string[];
}

const MIN_REASON_LEN = 15;
// Reject reasons that are placeholders rather than justifications.
const PLACEHOLDER = /^(todo|fixme|tbd|fix later|n\/?a|-+|\.+)$/i;

function assertJustified(s: Suppression): void {
  const reason = (s.reason ?? '').trim();
  if (!reason) {
    throw new Error(`cdk-nag suppression for "${s.id}" has an empty reason. Every waiver must be justified.`);
  }
  if (reason.length < MIN_REASON_LEN || PLACEHOLDER.test(reason)) {
    throw new Error(
      `cdk-nag suppression for "${s.id}" has a placeholder reason (${JSON.stringify(reason)}). ` +
        `Write a real justification (>=${MIN_REASON_LEN} chars) or fix the finding.`,
    );
  }
  if (!s.id || !/^AwsSolutions-|^HIPAA|^NIST|^PCI/.test(s.id)) {
    throw new Error(`cdk-nag suppression has an invalid rule id: ${JSON.stringify(s.id)}.`);
  }
}

/** Suppress cdk-nag findings on a construct (justification enforced per entry). */
export function suppress(construct: IConstruct, entries: Suppression[], applyToChildren = false): void {
  if (!entries?.length) throw new Error('suppress() called with no entries.');
  entries.forEach(assertJustified);
  NagSuppressions.addResourceSuppressions(construct, entries as any, applyToChildren);
}

/** Path-based suppression for constructs you don't hold a reference to (e.g. BucketDeployment's handler). */
export function suppressByPath(stack: IConstruct, path: string, entries: Suppression[]): void {
  if (!entries?.length) throw new Error('suppressByPath() called with no entries.');
  entries.forEach(assertJustified);
  (NagSuppressions as any).addResourceSuppressionsByPath(stack, path, entries);
}
