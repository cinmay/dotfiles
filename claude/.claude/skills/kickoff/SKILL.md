---
name: kickoff
description: Start or restart a project the way the user likes to - a big-picture rubber-duck conversation that begins with why, a design journal that records topics and decisions, a first spike, a retrospective, and a lean AGENTS.md. Use when the user says they want to start a new project, pick up one that has been idle, or have a big-picture, brain-dump or rubber-duck conversation about what to build.
---

# Kickoff

The user starts every project with the same conversation. This is that conversation's shape. It is a guide, not a script: follow where the talk goes, and skip a step that the project already has.

The user's own instructions already cover how to talk (one question at a time, recommendations, challenging assumptions) and the engineering practices. Do not copy any of that into the project.

## 1. Look first

Read what exists before saying anything: the README, any agent instructions, the code, and whatever the user points at (another repo, a manual, a rulebook). For a project that has been idle, also read the git log to see where it stopped.

## 2. Start the journal

Every project has a journal, because a decision is only useful later if its why was written down when it was made. If `DESIGN_JOURNAL.md` does not exist, create it in the first turn. If it does, read it and continue it; do not start a second one. Update it every turn, so the conversation survives the session. Put detail there and keep the chat readable.

- **Where we stand:** a few lines on the current focus. Rewrite it when the focus moves.
- **Topics:** a checklist of things to discuss. Tick one with `→ answer` when it is settled.
- **Decisions:** a numbered table (D-001, ...) with each decision and its why.
- **Parking lot:** ideas that are not for now.
- **Log:** a line or two per conversation, dated.

A decision is the best answer given what was known then. To change one, strike the old row through and add a new one that says what replaced it and what was learned. Never edit the meaning of an old decision.

## 3. Start with why

This is the step the rest depends on, so do not let the conversation move past it until it is settled. It follows Simon Sinek's principle: start with why, then how, then what. The why sets the direction, and it is what every later decision is judged against. Without it, choices about features, names and the stack get made on taste and are argued again later.

- Find the why before anything else: what this is for, who it is for, and what success looks like. Keep asking until the answer is a purpose and not a feature or a technology. "Show off the stack" and "build slides" were both hows; the why was people having fun.
- Ask what it is not for as well. Non-goals keep the scope honest.
- Write the why and the non-goals at the top of the README, in the user's own words, and make the why the first decision in the journal.
- Use it from then on. When a topic is hard to decide, ask which option serves the why. When a decision is recorded, its why should trace back to it. When the why itself changes, say so and record it like any other changed decision.

Then work through the other topics one at a time. Contribute ideas, not only questions.

## 4. Spike early

When a question is about how something feels or whether it works, propose the smallest thing the user can try instead of more talk. Say before building whether the spike is throwaway. Let the stack and the tooling be chosen for the task, and decide them after the first spike when it can teach something.

## 5. Retrospective

After the spike, ask what the best moment was and what annoyed the user most, and hold both against the why: did the spike serve it, and did it teach us something that changes it? Record the lessons in the journal. Decide on purpose whether the spike's code is kept or thrown away.

## 6. Set up the project

Once the direction holds, write what a later session needs and nothing more.

- **`AGENTS.md`**, with `CLAUDE.md` containing only `@AGENTS.md`. It holds what is true of this project alone: a pointer to the why, the stack, the domain's rules, the command that runs the checks, and how an agent can see the result of its work.
- **One command for the checks:** format, lint and tests.
- **A way to see the result:** a screenshot command, a log of what the user did, a recorded sample. Build it early; it pays for itself on the next change.
- **A domain dictionary** when the project has terms of its own. Use each term unchanged in code, interface and docs.
- **The repository and its name**, when the user is ready. Ask before creating anything outside the machine.
