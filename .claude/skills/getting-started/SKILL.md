---
name: getting-started
description: Orientation skill that runs on session startup. Teaches Claude about available skills and agents.
---

# Getting Started: You Have Superpowers

You have **skills** and **agents** available in this project.

- **Skills** (`.claude/skills/`) are predefined procedures that give you
  step-by-step instructions for common tasks. Invoke them with `/skillname`.
- **Agents** (`.claude/agents/`) are autonomous specialists that run in their
  own context. They handle explorative, multi-step work independently and
  return a summary. Use the Agent tool to launch them when the task matches
  their description.

They exist because someone already figured out the right way to do these things.

## Step 0: Name this session's feature branch

If this session is going to change code, give it a meaningful name BEFORE
your first push. The session branch starts with a random codename
(`claude/<adjective-scientist>-<id>`); without a name, the feature branch
and Railway environment inherit that random codename instead of describing
the work.

Derive a short kebab-case slug from what the user asked for (for example
"fix the login seed bug" becomes `fix-login-seed`), then run:

    bash .claude/scripts/set-feature-name.sh <slug>

This writes `.harness-feature`, commits it, and pushes, which triggers the
GitHub Action to create `feature/<slug>` and provision Railway under that
name. Run it once, early. It is idempotent and a no-op off a `claude/`
branch.

**Skip this** for read-only or question-only sessions (there is nothing to
push). If you forget, the fallback is graceful: the first push just uses
the random codename.

## Step 1: Discover your skills and agents

Run this now:

    bash .claude/scripts/list-skills.sh

This lists every skill and agent available in this project along with its
description.

## Step 2: Understand the rules

**Skills and agents are mandatory, not suggestions.**

When a skill or agent exists for a task the user is asking you to perform, you
MUST use it. Do not improvise a different approach. Do not skip it because you
think you already know what to do. Do not rationalize past it.

If you think there is even a 1% chance a skill or agent applies to what the
user is asking, check the list. Wrong invocations are acceptable. Skipping
the check is not.

Red flags that you are about to violate this rule:
- "I already know how to do this": check anyway
- "This is simple enough to do directly": check anyway
- "The skill is overkill for this": check anyway

## Step 3: Act

Run `bash .claude/scripts/list-skills.sh` RIGHT NOW, then proceed with
whatever the user has asked.
