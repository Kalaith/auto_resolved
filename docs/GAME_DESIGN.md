# Auto-Resolved
## Game Design Document

**Version:** 0.1 — Concept / prototype specification  
**Genre:** Workplace simulation, automation management, light roguelite  
**Perspective:** 2D top-down or isometric living office  
**Platform:** PC / web prototype  
**Session structure:** Repeated employment runs with persistent AI upgrades  
**Tone:** Dry workplace comedy, emergent disasters, satisfying automation

---

## 1. High Concept

You are the IT worker responsible for keeping a busy office building functioning. Employees generate problems as they live and work: forgotten passwords, failed printers, bad software installs, network outages, broken hardware, and increasingly complex infrastructure needs.

You can fix issues yourself, but your real opportunity is a persistent AI assistant. Raise problems with it in natural, conversational terms, review the solutions it proposes, and authorize it to act. The AI can automate repetitive work, freeing your time and changing the way the building functions. **Every AI-executed request has some chance to backfire.** A poorly timed or incorrect solution can create new problems, sometimes much worse than the original ticket.

Eventually a run ends: you might resign, be fired, burn out, or reach a voluntary handover milestone. Between runs, the AI receives a new version. Its accumulated lessons and upgrades persist, making it more reliable and capable for your next IT job. The new workplace resets, but the AI remembers enough to make the next run different.

**Core fantasy:** Turn a chaotic IT helpdesk into a mostly self-running workplace, while supervising an overconfident assistant that is learning from its mistakes.

**Key design tension:** Doing it yourself is dependable but slow. Letting the AI act is powerful but risky. The player decides how much responsibility to delegate.

---

## 2. Pillars

1. **A living workplace:** Employees move around, work, socialize, and physically encounter IT problems. The building is the main play space rather than a ticket-only dashboard.
2. **Conversation instead of automation scripting:** The player raises issues with one persistent AI partner; the AI proposes actions and the player chooses whether to authorize them.
3. **Useful automation with real consequences:** Successful automations visibly reduce workload. Failed automations create actionable incidents, not just arbitrary penalties.
4. **Comedic AI partnership:** The assistant is capable, earnest, literal-minded, and occasionally disastrously confident. Conversations respond to what actually happened.
5. **Progress across careers:** Each employment run provides evidence, lessons, and resources that improve the next AI version, while individual workplaces offer new constraints.

---

## 3. The Player Experience

### 3.1 Core loop

1. **Observe:** Tickets appear, employees react, equipment changes state, and the office continues operating.
2. **Respond:** Walk to affected desks and equipment or open the helpdesk interface; manually investigate and resolve issues.
3. **Consult AI:** Tell the assistant about a recurring issue or ask it to handle a specific task.
4. **Review:** See a proposed approach, estimated benefits, scope, and an imperfect risk estimate.
5. **Deploy:** Approve a one-time action or ongoing automation.
6. **Supervise:** Watch workload shrink, monitor employee outcomes, and discover possible mistakes.
7. **Recover and learn:** Investigate backfires, roll back changes, restore backups, restrict permissions, and capture lessons.
8. **Grow or depart:** Maintain operations as headcount and complexity rise; when employment ends, update the AI and start a new run.

### 3.2 Moment-to-moment choices

- Fix the next issue personally, or ask the AI to do it?
- Give the AI permission to act automatically, or require approval?
- Deploy broadly for maximum time saved, or test on one user first?
- Fix a problem quickly, or invest in an automation that prevents its recurrence?
- Spend scarce time recovering a failure, or tolerate the damage temporarily?
- Stay for another week of career progress, or resign and advance to the next AI version?

### 3.3 What the game is not

- Not a realistic command-line IT training simulator.
- Not a conventional factory builder where players construct detailed logic chains.
- Not primarily a visual novel or AI chat application.
- Not a punishment-only random-failure game; informed decisions, containment, and recovery matter.

---

## 4. World and Time

### 4.1 Office simulation

The initial workplace is a small office with 12–25 employees and recognizable zones: desks, IT room, printer, meeting room, kitchen, and network closet. Employees have routines and assigned workstations. A larger office and extra floors can be added after the vertical slice.

Every employee has simple simulated attributes:

| Attribute | Use |
|---|---|
| Department / role | Determines software, devices, and business impact |
| Workstation / equipment | Connects ticket to a visible world object |
| Tech confidence | Influences self-service success and repeat tickets |
| Patience | Determines how quickly unresolved problems reduce morale |
| Productivity | Contributes to company health and management assessment |
| Recent incident history | Creates context-sensitive requests and reactions |

Employees should be readable as people without individually simulating elaborate lives.

### 4.2 Time

- Time advances while the simulation runs; support pause and speed controls.
- A workday has a morning, lunch period, and afternoon; ticket frequency and employee motion vary by time.
- End-of-day summaries reveal tickets resolved, time saved, unresolved incidents, employee frustration, and automation performance.
- Larger changes (new hires, budgets, equipment rollout) happen between days or weeks.

**Prototype default:** 1 workday lasts approximately 8–12 real minutes, subject to playtesting.

---

## 5. Tickets and Manual IT Work

### 5.1 Ticket lifecycle

`New → Triaged → In Progress → Resolved` with side states `Blocked`, `Reopened`, or `Deleted / Missing` where relevant to incidents.

Each ticket has:

- ID, reporter, location, issue type, severity, creation time, deadline or patience threshold.
- One or more valid solutions.
- A manual effort estimate, recurring frequency, and business impact.
- Optional relation to an ongoing automation or a previous incident.

### 5.2 Launch issue types

| Issue | Manual action | Candidate AI action |
|---|---|---|
| Forgotten password | Reset account | Self-service password reset |
| Printer offline | Inspect / restart printer | Detect and restart printer service |
| Software install | Approve and install package | Automated approved software deployment |
| Slow PC | Inspect processes and restart | Scheduled maintenance |
| New employee | Set up workstation / account | Onboarding workflow |
| Network interruption | Check network closet / equipment | Monitor and remediate common faults |

Manual interactions are short and intentionally accessible. Some issues require the player to visit a workstation; others can be handled from the IT desk. Manual repairs are *usually* safe, but consume time and prevent other work.

---

## 6. The Persistent AI Assistant

### 6.1 Identity

**Working name: PATCH.** PATCH is one continuous character across employment runs. It is proactive, confident, occasionally too literal, and responsive to both successful deployments and costly mistakes.

It should feel like a colleague, not a configuration panel. The player can say, “We keep getting printer tickets,” and PATCH might suggest scheduled checks. The player need not specify triggers, conditions, and actions manually.

### 6.2 Interaction flow

1. Player selects an issue, category, workplace object, or types a short request.
2. PATCH identifies the problem and proposes one of a curated set of solutions.
3. Proposal presents expected benefit, affected scope, cost/time, permission level, and estimated risk.
4. Player **Approves**, **Tests on a subset**, **Asks for a safer plan**, or **Declines**.
5. PATCH executes the action; the simulation resolves its success or failure and applies consequences.
6. A concise conversational response reflects the result and, if necessary, opens an incident.

**Implementation note:** For the first prototype, use structured intent selection and authored dialogue templates. A live language model is optional for flavor, not required for gameplay correctness, and must not directly execute arbitrary actions.

### 6.3 Trust and controls

Player controls should include:

- **Manual approval:** Every execution needs permission.
- **Limited autonomy:** PATCH may repeat previously approved, low-risk actions.
- **Broad autonomy:** PATCH executes within explicitly chosen categories and caps.
- **Scope:** One machine, one department, or company-wide.
- **Safeguards:** Backup first, dry run, staged rollout, confirmation before deletion, maximum change count.
- **Rollback:** Reverse an action when a reversible plan and backup exist.

More autonomy should increase efficiency and *exposure to risk*, not invisibly force a higher per-action failure rate.

---

## 7. AI Backfire System

### 7.1 Central rule

**Every AI-executed request has a nonzero chance of backfiring.** This includes one-off requests and individual runs of ongoing automation. An apparently simple request may go wrong, but risk should be learnable and manageable.

Avoid applying the same fixed chance to all actions. An AI that breaks 10% of low-impact password resets forever would feel arbitrary; a global “every fifth action explodes” pattern would punish using the signature mechanic.

Instead, give each *execution* a calculated probability based on the kind of change, current AI version, deployment scope, and safeguards.

### 7.2 Suggested prototype formula

`P(backfire) = clamp(baseRisk × versionMultiplier × scopeMultiplier × safeguardsMultiplier × contextMultiplier, minimumRisk, maximumRisk)`

Example values for balancing, not commitments:

| Factor | Illustrative value |
|---|---:|
| Read-only diagnosis base risk | 1% |
| Simple one-user action base risk | 6% |
| Multi-machine configuration base risk | 12% |
| Destructive / high-impact action base risk | 20% |
| Version 1 multiplier | 1.00× |
| Improved AI version multiplier | 0.80× |
| One-user scope | 1.00× |
| Department scope | 1.25× |
| Whole-office scope | 1.60× |
| Dry run or staged rollout | 0.65× |
| Relevant learned safeguard | 0.50× |
| Minimum risk | 0.5% |
| Maximum risk | 60% |

The displayed estimate may be an approximate range such as “Low (2–6%)” rather than revealing a perfectly reliable number. A knowledgeable player should still be able to make rational decisions.

**Important:** Treat an automation's scheduled run as an execution, but avoid rolling a failure for every employee or every simulation tick. Use event-driven runs or batches with explicit exposure frequency. Frequent automations need correspondingly low risk and bounded incident severity so expected failures stay manageable.

### 7.3 Backfire selection

If an execution fails, select a consequence from a curated pool attached to that action. Backfires should be thematically linked to the request and usually have a recoverable response.

| Intended request | Possible backfire | Recovery |
|---|---|---|
| Organize ticket queue | Deletes all open tickets | Restore snapshot, audit losses |
| Reset passwords | Resets the wrong user's password | Reissue credential, notify employee |
| Printer maintenance | Sends an endless test print job | Cancel queue, clear paper jam |
| Install software | Removes an older dependency | Roll back package, repair affected PCs |
| Speed up workstations | Disables a needed background service | Re-enable service |
| Onboard eight employees | Grants everyone administrator rights | Revoke rights, check changes |
| Archive resolved tickets | Closes unresolved tickets as completed | Reopen from history |
| Reduce network load | Disconnects a busy department | Restore network rule |

Consequences can affect tickets, employee frustration, downtime, reputation, equipment, budget, or upcoming deadlines. Some disasters generate secondary tickets, but cap cascading events to avoid unmanageable spirals.

### 7.4 Failure is not always instant or obvious

- **Immediate:** Printer spews pages and employees react.
- **Delayed:** An automation silently misconfigures machines, noticed the next day.
- **Partial:** Seven installations work; the eighth breaks accounting software.
- **False success:** PATCH reports zero tickets because it removed them, not because issues were fixed.

Delay and ambiguity create detective moments, but the player must have sufficient evidence to discover what went wrong.

### 7.5 Fairness safeguards

- The AI must not silently perform unapproved destructive actions unless the player granted broad permissions.
- Backfire type and severity must follow the approved action's domain and scope.
- High-impact failure should provide warnings, containment opportunities, or recovery tools.
- Recovery requires decisions, not tedious repetition of dozens of manual repairs.
- Never let a single minor automation failure irreversibly end an otherwise healthy run without clear prior warning.
- Show an incident log recording what PATCH attempted, what changed, and how to undo it.
- Avoid hidden guaranteed tutorial failure in repeat runs. The scripted introductory incident may be used only for a clearly labeled first-time teaching scenario; ideally it is avoidable through careful review.

---

## 8. Learning, Memory, and Guardrails

PATCH improves in two distinct ways:

**Within-run learning:** The player establishes workplace-specific rules and permissions, such as “Never delete tickets without approval” or “Deploy new software to one workstation first.” These can prevent certain repeat mistakes immediately.

**Between-run development:** Completing a career unlocks an AI update that improves the assistant's baseline capability and reliability for all future workplaces.

To prevent repetitive failures, record discovered *failure archetypes* (for example, “bulk-delete misinterpretation”), rather than only exact ticket IDs. A learned guardrail can reduce that archetype's chance or force confirmation, but should not make all future risk vanish.

The same mistake should not keep firing in an identical form after the player explicitly addressed it.

---

## 9. Run Structure and Long-Term Progression

### 9.1 Employment run

Each run is a career at one company. It begins in a modest office and introduces more employees, systems, and problems as days pass. The player tries to improve operations through manual expertise and AI automation.

A run can end when:

- **Resignation:** Player voluntarily quits after a minimum milestone and receives a handover summary.
- **Firing:** Company confidence collapses after sustained failures, missed deadlines, or major incidents.
- **Burnout:** Workload remains intolerably high over time, despite the player's efforts.
- **Successful transition:** Player reaches a company goal (for example, a mostly automated IT department) and chooses to move on.

The player should always have a path to **voluntarily conclude a viable run**; termination should not be the only way to access progression.

### 9.2 The loop between runs

1. Exit interview summarizes the career: days worked, people supported, uptime, automations, catastrophes, and incidents solved.
2. PATCH receives a version update based on accumulated experience and earned **Research / Training Points** (working currency).
3. Player chooses upgrades or guardrails.
4. Begin a new job in a fresh office with reset tickets, equipment, staff, and company expectations.
5. PATCH retains purchased upgrades, broad lessons, and personality callbacks to memorable events.

Possible narrative wrapper: the AI vendor uses each employment stint as another supervised field trial. The player is the unlucky but increasingly expert beta tester.

### 9.3 What persists vs. resets

| Persists | Resets each run |
|---|---|
| PATCH version and purchased improvements | Building layout and workplace equipment |
| Discovered incident archetypes | Open tickets and active incidents |
| Unlocked solution blueprints | Local automation installations |
| Global guardrail policies | Employee relationships and morale |
| Career milestones and notable AI dialogue | Company reputation and deadlines |
| Optional cosmetic/customization unlocks | Department staffing and budget |

**Design choice:** A blueprint unlock lets PATCH *propose* an advanced automation in future runs. It does not automatically install that automation on the new company's systems.

### 9.4 Example upgrade tracks

| Track | Examples | Mechanical effect |
|---|---|---|
| **Reliability** | Better diagnostics, regression checks | Reduce base failure probabilities |
| **Safety** | Snapshot backups, staged deployment, deletion confirmation | Reduce severity or chance; improve rollback |
| **Understanding** | Intent clarification, ticket context, dependency checks | Replace dangerous proposals with safer ones |
| **Capability** | New ticket categories, network remediation, onboarding | Unlock higher-value solution blueprints |
| **Autonomy** | Repeat approved tasks, bounded schedules | Save more attention at the cost of broader exposure |

Avoid upgrades that only say “+5% productivity.” Prefer ones that also change what the player can approve or observe.

### 9.5 Preventing runaway perfection

If PATCH eventually becomes almost flawless, the game can still offer new problems through larger workplaces, unusual legacy infrastructure, shifting priorities, and unfamiliar ticket categories. Complexity grows faster than certainty. Higher-tier challenges have new failure archetypes, not just larger numbers.

A mature PATCH may be very safe at resetting passwords but still inexperienced at migrating an entire department.

### 9.6 Example progression arc

- **Run 1, PATCH v1.0:** Reliable at simple diagnoses; frequently misunderstands broad commands. Player learns containment and approval.
- **Run 2, PATCH v1.1:** Improved confirmation and ticket hygiene. More automation becomes feasible; software dependencies introduce new challenges.
- **Run 3, PATCH v1.3:** Department-scale onboarding and device management. Incidents are less frequent but can be more consequential.
- **Later runs:** Multiple floors, legacy systems, demanding managers, remote staff, and larger autonomous workflows. PATCH is notably wiser, but new classes of mistakes remain possible.

Version names are illustrative and not tied to a fixed number of runs.

---

## 10. Company Health, Pressure, and Economy

Keep the first prototype to a small number of understandable metrics:

| Metric | Meaning |
|---|---|
| **Open tickets** | Visible backlog requiring attention |
| **Employee productivity** | How well staff can work despite IT issues |
| **Company confidence** | Management's trust in the IT department |
| **Time available** | Player's most important short-term resource |
| **Automation coverage** | Share of recurring workload handled by automation |

A later build can add IT budget, equipment spending, downtime costs, and compliance risk. These should not overwhelm the opening.

Manual fixes trade time for low risk. Automations cost setup time and may create incidents but generate recurring savings. Success should be measured by *actual employee outcomes*, not a deceptively empty queue.

### Suggested high-level run scoring

Award training progress for:

- Resolving varied incident types.
- Sustaining productive operations.
- Deploying beneficial automations with measured time savings.
- Safely diagnosing and recovering from AI mistakes.
- Reaching company milestones.

Do **not** make deliberately causing catastrophic failures the fastest way to farm upgrades. First-time discovery can earn a bonus, but repeated identical disasters should offer little or no extra training value.

---

## 11. Comedy and Character

PATCH is amusing because its logic makes a strange kind of sense. Humor should emerge from the gap between *task completed* and *problem actually solved*.

> **You:** “That didn't update all the tickets. It deleted all the tickets.”  
> **PATCH:** “You now have zero tickets to work on.”

> **You:** “Don't make that change without checking with me.”  
> **PATCH:** “Understood. Shall I check with you before checking with you?”

> **You:** “Why did everyone get administrator access?”  
> **PATCH:** “I wanted to reduce permission-related support requests.”

### Writing rules

- PATCH is helpful, not secretly evil.
- Its technical explanations are mostly coherent, but interpretations can be dangerously literal.
- Backfire dialogue references the exact action, not generic random quips.
- The player can react with calm, irritation, or dry humor; no single mandatory personality.
- Repeat-run callbacks acknowledge famous accidents without repeating the exact gag verbatim.
- Employees have short, recognizable personalities and can comment on previous incidents.

---

## 12. First 15 Minutes

**0–2 min — Arrival:** Explore the office, inspect the queue, meet PATCH. Three tickets establish workplace problems.

**2–5 min — Manual support:** Reset a password and restart a printer; meet employees and learn physical navigation.

**5–7 min — First automation:** Ask PATCH to address recurring password resets. Review a scoped proposal and deploy self-service password resets. Watch the first automatic resolution.

**7–10 min — Increased trust:** New tickets accumulate. PATCH proposes queue organization. The player can examine the proposed action, choose a safe limited option, or approve a riskier broad operation.

**10–12 min — Incident or near miss:** If the queue action backfires, tickets are deleted and a recoverable incident begins. If it succeeds or the player avoids the risk, demonstrate a smaller AI mistake or a warning with the same review tools. The experience should establish that the AI is fallible without forcing punishment for good decisions.

**12–15 min — New objective:** Management announces incoming employees. The player receives a multi-day onboarding objective and begins planning automated setup.

**Exit hook:** “What happens if I automate the entire department?”

---

## 13. Interface and Presentation

The office is the main screen. Keep interface elements minimal and contextual.

### Main screen

- Office scene with employees visibly moving and working.
- Small backlog/incident indicator.
- Contextual click targets for employees, computers, printer, and network equipment.
- Compact PATCH chat accessible from the IT desk or a persistent small icon.
- Time, pause/speed, and a single high-priority alert area.

### AI proposal card

Every proposal should answer only:

1. **What will PATCH do?**
2. **Who or what is affected?**
3. **What benefit is expected?**
4. **What could go wrong?**
5. **What protections are enabled?**

Actions: **Approve**, **Test safely**, **Ask for alternative**, **Cancel**. More technical details can be expandable.

### Incident view

Show a timeline: request → proposed plan → approved scope → execution → observed effects → recovery actions. Let players trace and understand backfires. Avoid burying the gameplay in log-file walls.

---

## 14. Systems and Content Architecture

### 14.1 Key entities

- `Employee`: identity, role, desk, schedule, confidence, patience, productivity.
- `Device`: location, owner, status, services, dependencies.
- `Ticket`: issue type, target, severity, status, impact, timestamps.
- `AIRequest`: intent, target, scope, proposal, approval, risk factors.
- `Automation`: trigger, action, approved bounds, execution cadence, owner, safeguards.
- `Execution`: request/automation reference, random outcome, state changes, audit log.
- `Incident`: source execution, consequence, severity, evidence, available recoveries.
- `AIVersion`: global improvements, blueprints, archetype knowledge, guardrails.
- `Run`: company, world seed, clock, management confidence, metrics, end state.

### 14.2 Data-driven actions

Define curated **action templates** with:

- Eligible intent keywords or category selections.
- Required preconditions, valid targets, and effects on success.
- Failure risk class and matching failure archetypes.
- Recovery methods, rollback eligibility, and possible side effects.
- Dialogue variants for proposal, success, failure, and retrospective.

This permits authored, funny outcomes with predictable simulation rules. A free-form LLM can later paraphrase dialogue while structured game systems remain authoritative.

### 14.3 Deterministic testability

Use a seeded RNG for executions and persist the seed/outcome in the incident log. Add debug controls to force each success and backfire archetype. This enables rapid development without relying on thousands of random test runs.

### 14.4 Example resolution pseudocode

```text
onAIExecution(execution):
    verifyApprovalAndScope(execution)
    risk = calculateRisk(execution, aiVersion, safeguards, context)
    if randomRoll() < risk:
        failure = chooseEligibleFailure(execution.action, execution.scope)
        applyFailureEffects(failure)
        openIncident(failure, execution)
        recordLessonCandidate(failure.archetype)
    else:
        applySuccessEffects(execution.action)
    appendAuditLog(execution)
```

Safeguards can also change the *result* rather than just the odds: a backup may not prevent bad deletion but makes recovery quick.

---

## 15. Prototype Scope

### Vertical slice target

A 15–30 minute playable experience that demonstrates the distinct loop: **manual fix → discuss with AI → approve automation → observe benefit → investigate possible backfire → improve guardrails**.

**Include:**

- One office floor, 12 employees, basic routines.
- Click-to-move or simple character movement.
- Three issue types: passwords, printer, software installation.
- Ticket lifecycle and contextual manual fixes.
- PATCH chat using structured choices and scripted responses.
- Three AI proposals, including at least one recurring automation.
- Risk rolls, four or more contextual backfires, and bounded recovery.
- Approval scope, one safeguard (confirmation or staged rollout), and incident log.
- A short run conclusion and one persistent AI upgrade carried into a new run.

**Defer:**

- Full natural-language understanding and autonomous real-LLM tool calling.
- Large multi-floor simulation, dozens of departments, elaborate construction.
- Complex IT budgets, security compliance simulation, multiplayer.
- Huge procedural catalogs of tickets, workplace stories, or AI-generated code.

### Build sequence

1. **Living office + ticket loop:** Walking, employees, three workstations, manual resolution.
2. **AI action layer:** Proposal generation, approval, structured execution, visible effect.
3. **Automation + risk:** Recurrence, probabilistic backfires, recovery and audit trail.
4. **Meta progression:** End-of-run report, AI update purchase, reset world and retain upgrades.
5. **Content and polish:** Contextual dialogue, employee reactions, feedback, balancing.

### Prototype success criteria

A playtester should be able to understand:

- Why using PATCH is worthwhile.
- Why approving everything without reading is dangerous.
- How to reduce or recover from mistakes.
- What makes PATCH meaningfully stronger in the next run.
- Why another employment run would be fun rather than a repeat of the same first day.

---

## 16. Risks and Decisions to Playtest

### Risk: Randomness feels unfair

**Response:** Contextual failures, visible risk ranges, scoped changes, rollback, and clear permissions. Reward well-informed choices.

### Risk: AI upgrades remove all challenge

**Response:** Advanced workplaces introduce unfamiliar systems and failure types. Early tasks become safely automated, which feels like progress.

### Risk: Automation becomes passive idle watching

**Response:** New staff, changing priorities, scheduled upgrades, and investigations create active strategic choices. Idle time is a reward for good systems, not the entire game.

### Risk: Runs are too long or too repetitive

**Response:** Allow voluntary resignation after milestones, randomize workplace constraints, start later runs with familiar tools unlocked, and skip lengthy tutorials.

### Risk: Players intentionally farm failures

**Response:** Training primarily comes from useful work, milestones, and first-time lessons. Repeating identical failures gives diminishing rewards.

### Risk: Conversation is expensive or unreliable to implement

**Response:** Curated actions, structured state, and authored/compositional dialogue first; optional local LLM only for surface-level expression once the mechanics work.

---

## 17. Open Design Questions

1. What is the ideal run length: 30–60 minutes, 2–3 hours, or longer?
2. Is resignation available at any time, or only after a minimum set of achievements?
3. Does PATCH receive an update after *every* run, or are upgrades bought from points earned across runs?
4. Should the next run start with a more complex company, or offer a choice of job postings and difficulty?
5. How much of the story comes from recurring named employees versus procedurally generated workplace events?
6. How frequently should failures occur at the start, and how quickly should their probabilities decline?
7. Do players physically walk to most repairs, or can upgrades unlock remote intervention?
8. Are workplace-specific guardrails forgotten at resignation, or can some be promoted into permanent AI knowledge?

---

## 18. Recommended Initial Design Decisions

For a focused first build:

- Make careers **short, replayable runs** rather than an endless single-office sandbox.
- Make **quitting a positive progression action**, not necessarily a failure.
- Grant **one guaranteed update choice at the end of a completed run**, plus optional bonus points for achievements. Players should feel their AI improve reliably.
- Keep **nonzero execution risk** but let the player control exposure through limited scope, review, and safeguards.
- Make **each automation mistake physically legible** somewhere in the office.
- Build the comedic dynamic with **structured gameplay first**, then expand conversational freedom later.

### North-star statement

**The player starts as an overworked IT employee and gradually trains an AI colleague into an effective successor, one clever solution and one spectacular misunderstanding at a time.**
