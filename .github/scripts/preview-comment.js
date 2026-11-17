// Upserts the sticky Lamdera preview comment on a PR. Called from
// .github/workflows/preview.yml once the preview deploy is pushed.
module.exports = async ({ github, context }) => {
  const marker = '<!-- lamdera-preview -->';
  const pr = context.payload.pull_request;
  const sha = pr.head.sha;
  const runUrl = `${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}`;
  const env = process.env;

  const lines = [marker, `### Lamdera preview for \`${sha.slice(0, 7)}\``, ''];
  if (env.DEPLOY_RESULT === 'success') {
    lines.push(`**Preview:** ${env.PREVIEW_URL}`);
    lines.push('', '_Lamdera builds the preview after the push, so it may take a minute to update. Preview backends reset on every deploy._');
  } else {
    lines.push(`**Preview:** ❌ deploy ${env.DEPLOY_RESULT} ([logs](${runUrl}))`);
  }
  const body = lines.join('\n');

  const { data: comments } = await github.rest.issues.listComments({
    ...context.repo, issue_number: pr.number, per_page: 100,
  });
  const existing = comments.find((c) => c.body && c.body.includes(marker));
  if (existing) {
    await github.rest.issues.updateComment({ ...context.repo, comment_id: existing.id, body });
  } else {
    await github.rest.issues.createComment({ ...context.repo, issue_number: pr.number, body });
  }
};
