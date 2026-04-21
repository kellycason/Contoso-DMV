# Copilot Studio — Project Reference

Quick-reference for building Copilot Studio agents in this workspace using the **Skills for Copilot Studio** plugin (`microsoft/skills-for-copilot-studio`, installed as `coatsy.copilot-studio-skills` VS Code extension).

> **Do not re-fetch the GitHub repo.** Everything is bundled locally at:
> `c:\Users\kellycason\.vscode\extensions\coatsy.copilot-studio-skills-0.1.4\`

---

## Sub-Agents (use via `runSubagent` tool)

| Agent | When to use |
|-------|-------------|
| **Copilot Studio Author** | Create/edit topics, actions, knowledge, variables, child agents (YAML) |
| **Copilot Studio Manage** | Clone / push / pull / publish between local YAML and cloud; list environments |
| **Copilot Studio Test** | Run test suites, point-test utterances, analyze results |
| **Copilot Studio Troubleshoot** | Debug wrong topic routing, validation errors, unexpected behavior |

Always prefer the sub-agent over manual YAML editing — they know the schema and templates.

---

## Project Structure (per agent)

```
<agent-dir>/              # Find via: Glob **/agent.mcs.yml
├── agent.mcs.yml         # kind: GptComponentMetadata
├── settings.mcs.yml      # schemaName, GenerativeActionsEnabled, instructions
├── connectionreferences.mcs.yml
├── topics/*.mcs.yml      # kind: AdaptiveDialog
├── actions/*.mcs.yml     # kind: TaskDialog (connector actions)
├── knowledge/*.mcs.yml   # kind: KnowledgeSourceConfiguration
├── variables/*.mcs.yml   # kind: GlobalVariableComponent
└── agents/<child>/       # kind: AgentDialog (each in its own subfolder)
```

- **Never hardcode agent names.** Discover via `Glob: **/agent.mcs.yml`.
- All YAML uses `.mcs.yml` extension.

---

## Schema & Connector Lookup

Use the bundled scripts (from inside the plugin dir) rather than loading the full schema:

```bash
node scripts/schema-lookup.bundle.js search <keyword>
node scripts/schema-lookup.bundle.js lookup <DefinitionName>
node scripts/schema-lookup.bundle.js resolve <DefinitionName>
node scripts/schema-lookup.bundle.js kinds
node scripts/schema-lookup.bundle.js summary <DefinitionName>
node scripts/schema-lookup.bundle.js validate <file.yml>

node scripts/connector-lookup.bundle.js list
node scripts/connector-lookup.bundle.js operations <connector>
node scripts/connector-lookup.bundle.js operation <connector> <opId>
node scripts/connector-lookup.bundle.js search <keyword>
```

**NEVER load `reference/bot.schema.yaml-authoring.json` directly — too large.**

---

## Triggers (topics)

Two routing mechanisms — which is used depends on orchestration mode:
- **Generative** (`GenerativeActionsEnabled: true`): AI uses `modelDescription`
- **Classic**: pattern-matches `triggerQueries`

| Kind | Purpose |
|------|---------|
| `OnRecognizedIntent` | User utterance matches |
| `OnConversationStart` | Conversation begins |
| `OnUnknownIntent` | Fallback — no topic matched |
| `OnEscalate` | User asks for human |
| `OnError` | Error handling |
| `OnSystemRedirect` | Triggered only via redirect |
| `OnSelectIntent` | Disambiguation |
| `OnSignIn` | Auth required |
| `OnToolSelected` | Child agent invocation |
| `OnKnowledgeRequested` | Custom knowledge search (YAML-only) |
| `OnGeneratedResponse` | Intercept AI response before send |
| ~~`OnOutgoingMessage`~~ | **Broken — do not use** |

---

## Action Kinds (inside topics)

| Kind | Purpose |
|------|---------|
| `SendActivity` | Send message |
| `Question` | Ask user |
| `SetVariable` | Power Fx assignment (prefix `=`) |
| `SetTextVariable` | Template string (uses `{}`) — good for type conversion |
| `ConditionGroup` | Branching |
| `BeginDialog` / `ReplaceDialog` / `EndDialog` | Topic control |
| `CancelAllDialogs` / `ClearAllVariables` | Reset |
| `SearchAndSummarizeContent` | Generative answer grounded in knowledge |
| `AnswerQuestionWithAI` | AI answer (convo + general knowledge only) |
| `EditTable` | Modify collection |
| `OAuthInput` | Sign-in |
| `SearchKnowledgeSources` | Raw knowledge search |
| `CreateSearchQuery` | AI-built search query |
| `CSATQuestion` | Customer satisfaction |
| `LogCustomTelemetryEvent` | Logging |

---

## Connector Actions (TaskDialog)

File: `actions/<name>.mcs.yml`, `kind: TaskDialog`, `action.kind: InvokeConnectorTaskAction`

- **Input kinds**: `AutomaticTaskInput` (AI fills it) or `ManualTaskInput` (hardcoded string)
- **Connection mode**: `Maker` (service credentials) or `Invoker` (end user)
- **OData `$`-params** (e.g., `$filter`, `$top` in SharePoint):
  - In TaskDialog: `propertyName: "'$filter'"` (YAML double + literal single quotes)
  - In inline `InvokeConnectorAction` in topics: `parameters/$filter: "..."`

Use the **Author** sub-agent (`/copilot-studio:add-action`) rather than hand-writing.

---

## Variables

| Prefix | Scope |
|--------|-------|
| `Topic.<name>` | Current topic only |
| `Global.<name>` | Entire conversation (file in `variables/`) |
| `System.<name>` | Built-in, read-only |

Global var `aIVisibility`:
- `UseInAIContext` → orchestrator reads it
- `Hidden` → internal flags, orchestrator unaware

**First assignment** uses `init:` prefix: `variable: init:Topic.UserEmail`.

### Key System Variables

`System.Activity.Text`, `System.Conversation.Id`, `System.Conversation.InTestMode`, `System.FallbackCount`, `System.Error.Message`, `System.Recognizer.SelectedIntent`, `System.SearchQuery` / `System.SearchResults` (in `OnKnowledgeRequested`), `System.ContinueResponse` / `System.Response.FormattedText` (in `OnGeneratedResponse`).

---

## Power Fx in YAML

- Expressions start with `=`
- String interpolation uses `{}` (no leading `=`): `"Error: {System.Error.Message}"`
- **Only the supported function list works** — see `skills/int-reference/SKILL.md` for full list
- Record literals: `"={ DisplayName: ..., TopicId: \"x\" }"`

---

## Best Practices (load on demand)

Located in `skills/best-practices/`:

| File | Use when |
|------|----------|
| `jit-glossary.md` | Customer acronyms, terminology CSV on conversation start |
| `jit-user-context.md` | Country/department-aware personalization via M365 profile |
| `Topic-redirect-withvariable.md` | Replace if/else chains with `Switch()` in `BeginDialog` |
| `prevent-child-agent-responses.md` | Child agent returns data instead of messaging user |
| `date-context.md` | Give orchestrator awareness of "today" for relative dates |

Combine glossary + user-context into a single `conversation-init` topic (template at `templates/topics/conversation-init.topic.mcs.yml`).

---

## Templates Available

**Topics**: greeting, fallback, arithmeticsum, question-topic, search-topic, custom-knowledge-source, remove-citations, auth-topic, error-handler, disambiguation

**Other**: agent, connector-action (generic), public-website knowledge, sharepoint knowledge, global-variable

Full paths: `c:\Users\kellycason\.vscode\extensions\coatsy.copilot-studio-skills-0.1.4\templates\`

---

## Skills Available

In `skills/`: `add-action`, `add-adaptive-card`, `add-generative-answers`, `add-global-variable`, `add-knowledge`, `add-node`, `add-other-agents`, `best-practices`, `chat-directline`, `chat-sdk`, `chat-with-agent`, `clone-agent`, `create-eval`, `detect-mode`, `directline-chat`, `edit-action`, `edit-agent`, `edit-triggers`, `known-issues`, `list-kinds`, `list-topics`, `lookup-schema`, `manage-agent`, `new-topic`, `run-tests`, `validate`.

**Skill-first rule**: always invoke the matching skill/sub-agent before writing YAML manually.

---

## Conventions & Gotchas

- **ID generation**: random alphanumeric, 6–8 chars after prefix (e.g., `sendMessage_g5Ls09`)
- Always replace `_REPLACE` placeholder IDs in templates
- Validate every manually-written YAML with `validate` skill
- **YAML-only features** (work at runtime but invisible in Studio UI — warn user UI edits may drop them):
  - `triggerCondition` with arbitrary Power Fx on knowledge sources
  - `OnKnowledgeRequested` custom knowledge source topics
