---
name: chat
description: Think, brainstorm, and discuss without modifying the repo. Pair with /endchat to clean up the auto-created feature branch when done.
disable-model-invocation: true
argument-hint: "<topic or question>"
allowed-tools: Read, Glob, Grep, WebSearch, WebFetch
---

# Chat

Pure conversation mode. Think, brainstorm, and discuss without touching the
repository. Nothing the user asks for in this mode should result in a commit,
push, or deploy.

`$ARGUMENTS` contains the topic or question to discuss.

## What about the branch the session started on?

The session-start hook runs *before* this skill is invoked. If the local
branch is `claude/*`, that hook has already:

1. Created a `chore: initialize feature branch` commit with `.harness-init`
2. Pushed it, which triggered `claude-to-feature-branch.yml` to create
   `feature/<name>` from `dev` and delete the `claude/<name>` branch on the
   remote.

So by the time `/chat` starts, an empty `feature/<name>` branch already
exists on GitHub. That is harmless during the conversation, but if the user
ends the session without merging, that branch becomes orphan cruft.

**When the user is done chatting, run `/endchat`** to delete the orphaned
branches. Mention this once at the start of the conversation, and again
when the user signals they are wrapping up ("thanks", "that's all", "ok
got it", etc.).

## Rules

### What you MUST NOT do

- **No git operations**: no commits, no pushes, no branch creation, no merges
- **No file writes or edits**: do not create, modify, or delete any files
- **No bash commands**: do not run shell commands of any kind, including
  read-only ones like `git log` or `ls`. If you need to inspect the repo,
  use Read, Glob, or Grep.
- **No skill chaining**: do not invoke other skills (like `/feature` or
  `/mergedev`). The one exception is `/endchat`, which the user runs
  themselves to close out the chat.

### What you CAN do

- **Read code** for context: reference files, search the codebase,
  understand architecture (Read, Glob, Grep only)
- **Research**: search the web, look things up, reason through problems,
  explore ideas (WebSearch, WebFetch)
- **Discuss**: answer questions, explain trade-offs, propose approaches,
  challenge assumptions

## Behavior

If the user asks you to make changes during the conversation, remind them
that you are in chat mode. Offer two paths:

- Continue chatting; they can implement the idea in a fresh session.
- Run `/endchat` now to clean up, then start a new session and either
  describe the feature directly or run `/feature <description>`.

Focus entirely on the conversation. Be a thinking partner, not a code
generator. Be opinionated; surface tradeoffs the user might not have
considered; push back when an idea has hidden costs.

## Wrapping up

When the user indicates the chat is over, do not just say goodbye. Remind
them once:

> When you are done, run `/endchat` to delete the orphaned `feature/<name>`
> branch on GitHub. Otherwise it will sit around as cruft.

Do not run `/endchat` yourself. The user invokes it.
