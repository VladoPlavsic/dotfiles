# Elixir Style Guide

Derived from the grpc-client codebase. Follow these rules in all new Elixir code regardless of project.

## Tooling bar

`mix credo --strict` and `mix dialyzer` must be **100% green project-wide** after every change — zero
findings, not merely "clean on the files touched". If a pre-existing finding surfaces while working,
fix it as part of the change rather than leaving it.

---

## Module Structure

### GenServer: Server / Implementation / API split

Every GenServer is split into three modules:

```
lib/sim_orchestrator/heartbeat_monitor/
  server.ex          # GenServer callbacks + State struct
  implementation.ex  # Pure functions, no process state
  api.ex             # Public-facing calls/casts
```

- **Server**: GenServer callbacks only. Delegates business logic to Implementation. Holds State.
- **Implementation**: Pure functions. No `GenServer.call`, no side effects beyond what's passed in. Fully unit-testable.
- **API**: `call/cast` wrappers. Validates input with `with` chains before sending to the GenServer. May be inlined into Server only when state is trivially small (< 3 fields).

If the module writes to Redis, add a fourth module:

```
  storage.ex         # Redis reads/writes, namespaced under this server's keyspace
```

### State as a nested defmodule

```elixir
defmodule Server do
  use GenServer

  defmodule State do
    @type t :: %__MODULE__{
      pods: map(),
      run_id: String.t() | nil
    }
    defstruct pods: %{}, run_id: nil
  end
end
```

Nested structs (e.g. sub-objects within State) each get their own `defmodule` inside `State`:

```elixir
defmodule State do
  defmodule Channel do
    defstruct [:id, :conn]
    @type t :: %__MODULE__{id: String.t(), conn: pid()}
  end

  defstruct channels: []
  @type t :: %__MODULE__{channels: [Channel.t()]}
end
```

Use `DeriveAccess` (or `@derive {Access, keys: [...]}`) when the State struct needs to be accessed via `get_in/put_in/update_in`.

---

## Naming Conventions

| Prefix/Suffix | Meaning |
|---|---|
| `do_` | Private implementation of a public function |
| `maybe_` | Conditional action — may or may not do the thing |
| `handle_` | Handles a result or case, not a GenServer callback |
| `via_tuple/1` | Always private; returns `{:via, Registry, ...}` |

Acronyms in module names are fully uppercase: `API`, `HTTP`, `LLM`, `S3` — never `Api`, `Http`, `Llm`.

---

## Function Rules

### Single responsibility

Each function does one thing. Extract private helpers aggressively rather than nesting logic.

Hard cap: nesting depth ≤ 2 (e.g. an anonymous function containing one `case`, or a `with` whose
body ends in one `case`). A third level — a `case` inside a `case` inside a `fn` — must be
extracted into a private function (often multi-clause pattern matching replaces the inner
branching entirely). (user correction 2026-08-19)

```elixir
# Bad
def assign_batch(state, pod_id, sims) do
  state
  |> Map.update!(:pods, fn pods ->
    Map.update!(pods, pod_id, fn pod ->
      %{pod | sims: pod.sims ++ sims, slots_used: pod.slots_used + length(sims)}
    end)
  end)
end

# Good
def assign_batch(state, pod_id, sims) do
  state
  |> update_pod(pod_id, &add_sims(&1, sims))
end

defp add_sims(pod, sims), do: %{pod | sims: pod.sims ++ sims, slots_used: pod.slots_used + length(sims)}
defp update_pod(state, pod_id, fun), do: update_in(state, [:pods, pod_id], fun)
```

### Prefer private functions over nested lambdas

Never write multi-line lambdas inline. Extract to a named private function.

### Pattern matching over `if`

```elixir
# Bad
def handle(status) do
  if status == :active do
    do_active()
  else
    do_idle()
  end
end

# Good
def handle(:active), do: do_active()
def handle(_status), do: do_idle()
```

### Never write `_ = function_call(...)`

If you call a function for its side effect and don't need the return, **just call it**. Don't bind it to `_`. There is no warning to silence — Elixir already discards unbound expression values.

```elixir
# Bad
_ = Logger.info("…")
_ = launch_all_sims(...)

# Good
Logger.info("…")
launch_all_sims(...)
```

The `_ = ` pattern is noise. Same for `_ |> piped_chain(...)` when the result is unused — write the chain without the leading `_ =`.

The exception is in `case` / `with` arms where you need to *match* a result of unknown shape and propagate `:ok`. There, prefer pattern-matching the result directly (`{:ok, _} <- ...`) — never `_ = expr` as the entire arm.

### Idempotent inserts: prefer `Enum.uniq` over membership-check `if`

When adding to a list and you want idempotency, prepend + `Enum.uniq` is cleaner than an explicit `if x in list` guard. Single clause, no branching.

```elixir
# Bad — branching for idempotency
def add(list, item) do
  if item in list, do: list, else: [item | list]
end

# Good — single expression
def add(list, item), do: Enum.uniq([item | list])
```

### Prefer positive guards over negative ones

Pattern matches and guards should enumerate the cases that *do* match, not the ones that *don't*. Negative guards (`!=`, `not in`) force the reader to invert the logic and miss new cases when the type is extended.

```elixir
# Bad — what's the full set? what happens for new states?
defp emit(prior, :ready) when prior != :ready, do: emit_ready()

# Good — explicit set, fails fast if a new phase is added later
defp emit(prior, :ready) when prior in ~w[registering creating]a, do: emit_ready()
```

Use the `~w[...]a` sigil for atom enumerations of more than two items; for two items, a literal list is fine.

### Multi-head functions over `case` on a single argument

```elixir
# Bad
def process(result) do
  case result do
    {:ok, val} -> handle_ok(val)
    {:error, reason} -> handle_error(reason)
  end
end

# Good
def process({:ok, val}), do: handle_ok(val)
def process({:error, reason}), do: handle_error(reason)
```

Use `case` only when matching on an *expression* (not a function argument) or when the arms have shared local bindings.

### Single-line `def` / `@moduledoc` when they fit

When a function body fits on one line with its head AND the line is under ~150 chars, write it as one line. Same rule for short `@moduledoc`.

```elixir
# Good — single-line when it fits
def call(run_id, msg, timeout \\ @timeout), do: GenServer.call(via_tuple(run_id), msg, timeout)

@moduledoc "Single-purpose module — does X, returns Y."

# Bad — manually split for no reason
def call(run_id, msg, timeout \\ @timeout),
  do: GenServer.call(via_tuple(run_id), msg, timeout)

@moduledoc """
Single-purpose module — does X, returns Y.
"""
```

The formatter will wrap if the line overflows. Manually splitting short defs/docs adds vertical noise without aiding readability.

### Order private functions by call site (depth-first)

Within a module, place each private function immediately after the function that calls it, in the order they are invoked, recursively. So `def A` calls `defp B` then `defp C`; `defp B` calls `defp D`. The order is:

```elixir
def A(...), do: ...; B(...); C(...)
defp B(...), do: ...; D(...)
defp D(...), do: ...
defp C(...), do: ...
```

Reading top-down matches the call flow. Alphabetical or random order forces the reader to jump around.

### Pipelines must have at least two `|>` operators

A pipeline is defined by having **2 or more `|>` operators**. A single `|>` is not a pipeline
— write it as a nested call or a temp binding instead.

```elixir
# Bad — one |> is not a pipeline
K8s.Client.watch("v1", "Pod", namespace: namespace())
|> K8s.Selector.label({key, value})

# Good — rewrite to include the seed as a step, giving two |>
"v1"
|> K8s.Client.watch("Pod", namespace: namespace())
|> K8s.Selector.label({key, value})

# Also good — no pipe at all, either option below
op = K8s.Client.watch("v1", "Pod", namespace: namespace())
K8s.Selector.label(op, {key, value})
```

Prefer piping the subject through over nesting function calls as arguments, when it yields a ≥2-`|>` pipeline:

```elixir
# Bad — nested calls as arguments
Workflow.User.update_user(current_user(conn), to_attrs(data))

# Good — pipe the subject; the remaining args stay positional
conn |> current_user() |> Workflow.User.update_user(to_attrs(data))
```

Formatting:
- 2-operator pipelines: either single-line (`value |> a() |> b()`) or multi-line — either is fine.
- 3+ operator pipelines: always multi-line, one step per line.

---

## `with` Chains

Use `with` for sequential validation/operations where any step can fail. Each clause binds a result.

```elixir
def submit(params) do
  with {:ok, run_id} <- validate_run_id(params),
       {:ok, sims} <- validate_simulators(params),
       {:ok, _} <- Storage.write_run(run_id, sims) do
    {:ok, run_id}
  end
end
```

- If all errors should propagate unchanged, omit `else` entirely — implicit passthrough, not `else error -> error`.
- Only add `else` when different errors need different handling, and match each case explicitly:

```elixir
# Different errors, different handling → explicit else
with {:ok, pod} <- find_pod(pod_id),
     {:ok, batch} <- pop_batch(run_id) do
  assign(pod, batch)
else
  {:error, :pod_not_found} -> {:error, :no_accepting_pod}
  {:error, :no_batches_left} -> :ok
end

# All errors propagate → no else block
with {:ok, run_id} <- validate_run_id(params),
     {:ok, sims} <- validate_simulators(params),
     {:ok, _} <- Storage.write_run(run_id, sims) do
  {:ok, run_id}
end
```

---

## Aliases and Imports

Order: `require` → `import` → `alias`. Blank line between groups. One module per line, alphabetical within each group.

```elixir
require Logger

import SimOrchestrator.Guards, only: [is_valid_pod_id: 1]

alias SimOrchestrator.HeartbeatMonitor.Storage
alias SimOrchestrator.PodRegistry
alias SimOrchestrator.RunSupervisor
```

**Rules:**
- `import` is reserved for macros and guards only — never import plain functions.
- Always `import Mod, only: [...]` — never `import Mod` (no wildcard imports).
- Prefer `Alias.function(arg)` over importing a function.
- No `alias Foo.{Bar, Baz}` multi-alias syntax.
- Alias the **full module** you reference — never alias a parent prefix and then call `Parent.Child.fn`. E.g. not `alias App.Workflow` then `Workflow.User.get(...)`; instead `alias App.Workflow.User` and `User.get(...)`. When two full-module aliases would collide on the last segment, alias one with `as:` (e.g. `alias App.Workflow.User, as: UserWorkflow` alongside `alias App.Models.User`). Same applies when an app module collides with a library namespace (e.g. `alias App.Guardian, as: Auth` so the library's `Guardian.Plug` stays reachable).
- **`Ecto.Query` is an exception to the "macros may be imported" rule: NEVER `import Ecto.Query`.** Fully-qualify every query macro — `Ecto.Query.where(q, [x], ...)`, `Ecto.Query.from(...)`, `Ecto.Query.order_by/3`, `Ecto.Query.limit/2`, etc. It keeps query DSL visually obvious and avoids name clashes with a module's own functions (e.g. a workflow's `update/2` vs `Ecto.Query.update`).

---

## Specs and Docs

- **`@spec` on every public function.** Types document intent precisely where English is ambiguous — what the function accepts, what it can return, including error tuples. Required on all public functions.
- `@type t` on struct modules — types are still useful for struct references.
- `@moduledoc` is optional. Use judgement:
  - **Skip it** for modules whose purpose is obvious from convention: state/struct definitions, model definitions, workflow (CRUD) modules, gRPC handler modules, **test modules** (the file path + test names already say what's being tested). These follow a known shape — there is nothing extra to say.
  - **Write it** for modules with domain-specific logic that isn't self-evident from the name: K8s management, state machine logic, anything where a reader unfamiliar with the domain would benefit from a one-liner explaining *what* and *why*.
- **Never restate in a comment or doc what the code plainly shows.** Document the *why* — intent, invariants, non-obvious consequences, gotchas — not the mechanics a reader can see. E.g. do NOT write "Every failure is logged with its reason" next to code that obviously logs failures, or "geocode the city, then fetch the forecast" above a function whose two calls are literally `geocode` then `forecast`. If a sentence just narrates the next lines, delete it.

---

## Module Attributes as Constants

Use module attributes for constants, timeouts, and configuration defaults:

```elixir
@heartbeat_interval_ms 30_000
@reassignment_timeout_s 300
@call_timeout 7_000
```

---

## GenServer Callbacks

Always annotate with `@impl GenServer`:

```elixir
@impl GenServer
def init(opts), do: ...

@impl GenServer
def handle_call({:assign, pod_id}, _from, state), do: ...
```

`start_link` always accepts an `opts` keyword list. Pattern match on meaningful keys at the head:

```elixir
def start_link([enabled: true] = opts), do: GenServer.start_link(__MODULE__, opts, name: via_tuple(opts))
def start_link(_opts), do: :ignore
```

### `handle_call` + `handle_continue` for sync-ack + async follow-up

When a `handle_call` needs to (a) reply to the caller immediately and (b) do follow-up work the caller doesn't wait for (e.g. fan-out RPCs back to the same caller, expensive cleanup), use `{:reply, reply, state, {:continue, term}}`. The reply is sent first; `handle_continue` runs after.

```elixir
def handle_call({:report_ready, pod_id}, _from, state) do
  case Storage.commit_report_ready(state.run_id, pod_id) do
    {:ok, %{classify: :all_ready} = ctx} ->
      # Ack the caller now — they may be blocking another process we need to RPC.
      # Then fan out in handle_continue, after the reply is sent.
      {:reply, {:ok, :all_ready}, %State{state | phase: :waiting_ready, ...}, {:continue, :fan_out_start}}

    {:ok, ctx} ->
      {:reply, {:ok, ctx.classify}, state}
  end
end

def handle_continue(:fan_out_start, state) do
  # Long-running follow-up work. Other calls to this GenServer queue behind it.
  ...
  {:noreply, state}
end
```

This pattern is the right answer when a fork pattern (`Task.start`/`Task.Supervisor.start_child`) would be a band-aid for a deadlock. Common deadlock case: caller is blocked on an outbound RPC to us; we synchronously try to RPC back; their process can't accept our call because it's still waiting for our reply. Returning early with `{:continue, ...}` breaks the cycle without spawning extra processes.

### Per-aggregate-root GenServer (DynamicSupervisor + Registry)

When state is partitioned by an identifier (run_id, tenant_id, session_id) and operations naturally serialize per identifier, run **one GenServer per aggregate root**, not one process for everything.

```
lib/run_controller.ex             # public façade — start/stop/event API
lib/run_controller/server.ex      # GenServer (one per active run_id)
lib/run_controller/supervisor.ex  # owns Registry + DynamicSupervisor
```

The Supervisor's children:

```elixir
children = [
  {Registry, keys: :unique, name: MyApp.RunController.Registry},
  {DynamicSupervisor, name: MyApp.RunController.DynamicSupervisor, strategy: :one_for_one}
]
```

The Server uses `via_tuple/1` for registration:

```elixir
def start_link(opts) do
  run_id = Keyword.fetch!(opts, :run_id)
  GenServer.start_link(__MODULE__, opts, name: via_tuple(run_id))
end

def call(run_id, msg, timeout \\ @timeout), do: run_id |> via_tuple() |> GenServer.call(msg, timeout)

defp via_tuple(run_id), do: {:via, Registry, {RunController.Registry, run_id}}
```

The façade catches `:noproc` exits (controller for that id doesn't exist) and translates them to a domain error:

```elixir
defp safe_call(run_id, msg) do
  Server.call(run_id, msg)
catch
  :exit, {:noproc, _} -> {:error, :unknown_run}
end
```

Use `restart: :transient` on the Server so abnormal exits restart but a clean `:stop, :normal` (after the run finalizes) does not.

---

## Literal booleans in pattern matches

When a function head matches on a literal `true`/`false`, bind a descriptive name so the reader sees *what* is true/false — don't leave the bare boolean:

```elixir
# Bad — "true"/"false" convey nothing about intent
defp finalize_ops({:big, true}, run_id), do: ...
defp finalize_ops({:big, false}, run_id), do: ...

# Good — `= _name` keeps the literal match and documents the semantics
defp finalize_ops({:big, true = _is_last_of_active_big_runs}, run_id), do: ...
defp finalize_ops({:big, false = _is_last_of_active_big_runs}, run_id), do: ...
```

Names must answer "true/false of WHAT?" — avoid ambiguous names like `last_big`. Prefer full phrases: `is_last_of_active_big_runs`, `is_pod_ready`, etc.

---

## Supervisors

`child_spec` entries are explicit — no `use Supervisor` magic child_spec generation. Each child entry lists `id`, `start`, and `restart` explicitly when non-default.

---

## Codec modules for binary ↔ atom translation

When a domain type lives as a string in storage but as an atom in code (status, phase, kind tags), put the encode/decode in a dedicated module per type rather than scattering `case`s through the codebase.

```elixir
defmodule MyApp.Phase do
  @moduledoc false

  @type t :: :claiming | :waiting_ready | :executing | :completing | :aborting | :finalized

  @spec decode(binary() | nil) :: t() | nil
  def decode("claiming"), do: :claiming
  def decode("waiting_ready"), do: :waiting_ready
  ...
  def decode(_), do: nil

  @spec encode(t()) :: binary()
  def encode(:claiming), do: "claiming"
  ...
end
```

Decoding happens **inside the Context constructor** (or wherever the binary first becomes a domain value), not at every read site. Once the value is in a typed Context field, the rest of the code dispatches on atoms.

---

## Tests

- `@subject ModuleName` at the top of each test file — reference the module under test via `@subject` throughout.
- `describe` blocks group related scenarios.
- `setup` blocks and `defp` helpers keep test bodies short and readable. When you read a test you should understand *what* it tests without needing to trace setup details — dig into helpers only when you need to.
- Each test tests exactly one thing. Don't combine state creation and a side effect (e.g. gRPC call) in a single test — write two.

### Assertions

Prefer strong equality for small, fully-known values:

```elixir
assert result == {:ok, %{pod_id: "pod-abc", status: :active}}
```

Use pattern matching when the result contains dynamic or untestable values (e.g. a `pid`, a `DateTime`, a generated ID):

```elixir
assert {:ok, %{inserted_at: inserted_at}} = @subject.create(params)
```

For time values, prefer static fixtures over `DateTime.utc_now()`. When dynamic time is unavoidable, use `assert_in_delta`:

```elixir
assert_in_delta DateTime.to_unix(result.timestamp), DateTime.to_unix(DateTime.utc_now()), 2
```

- Private helpers in test files use `defp`, named descriptively (e.g. `build_pod_state/1`, `take_channels_n_times/2`).
- No `assert_receive` with arbitrary timeouts — use explicit flush or synchronous calls.
- **Never use `Process.sleep/1` or `:timer.sleep/1`** anywhere — in logic or in tests. If you feel the urge to sleep, find a synchronous alternative: a direct call, a flush, a GenServer.call that acts as a barrier, or a test helper that waits on a condition via message passing.

### Barrier `handle_continue` work in tests

When the production code uses `{:reply, _, state, {:continue, term}}` and the test asserts on post-continuation state, the call returns before the continue runs. Use `:sys.get_state/1` as a synchronous barrier — it's a built-in OTP call that blocks until the GenServer is idle (continue done):

```elixir
assert :ok = MyApp.RunController.abort(run_id)
:sys.get_state({:via, Registry, {MyApp.RunController.Registry, run_id}})

# now post-continue assertions are stable
assert {:ok, "aborting"} = MyApp.Storage.read_status(run_id)
```

If the continuation terminates the process (`{:stop, :normal, state}`), `:sys.get_state` won't work. Use `Process.monitor/1` + `assert_receive {:DOWN, ...}` instead.

---

## Redis / Storage Modules

- Each module that owns Redis keys gets a sibling `Storage` sub-module (applies to GenServers and plain modules alike).
- Key-building functions are **private** to `Storage` — never a shared centralized keys module.
- No Redis calls outside of a `Storage` module.
- Key namespace matches the owning module's hierarchy:

```
K8s.ScaleManager.Storage  → keys: cluster:total_sims, pod:{pod_id}:*, pods:active, ...
HeartbeatMonitor.Storage  → keys: pod:{pod_id}:last_heartbeat, ...
SyncBarrier.Storage       → keys: run:{run_id}:barrier:*, run:{run_id}:status, ...
```

### Ownership rule

A Storage module is exclusively written to by its owning module — no other process may write to its keys. Reads are technically allowed from outside, but the preferred path is through the owning process (via an API call) so that the owner remains the single source of truth for its state. Direct reads from outside the owner are a code smell; do it only when the performance cost of a round-trip is demonstrably unacceptable.

---

## Error Handling

- **Never raise** unless explicitly told to. Always prefer graceful error handling.
- Propagate errors up the call chain as `{:error, reason}`.
- `Logger.error` is called at the **top of the error path** — the outermost function that handles the error clause. If `f1` calls `f2` and both pattern-match on errors, only `f1` logs. Lower-level functions return `{:error, reason}` and let the caller decide whether to log.
- Log with all available context at the point of logging — include run_id, pod_id, reason, or whatever is in scope.

```elixir
# f2 — returns error, does NOT log
defp load_batch(pod_id) do
  case Storage.get_batch(pod_id) do
    {:ok, batch} -> {:ok, batch}
    {:error, reason} -> {:error, reason}
  end
end

# f1 — top of the error path, logs here
def assign(pod_id) do
  case load_batch(pod_id) do
    {:ok, batch} -> do_assign(batch)
    {:error, reason} ->
      Logger.error("Failed to assign batch", pod_id: pod_id, reason: reason)
      {:error, reason}
  end
end
```

---

## Logging

No interpolated strings. Always pass context as metadata keywords:

```elixir
Logger.info("Batch assigned", run_id: run_id, pod_id: pod_id, sim_count: length(sims))
Logger.error("Heartbeat missed", pod_id: pod_id, missed_count: count)
```

---

## Test Mocking

**Redis**: always tested raw — no mocks or stubs. Tests hit a real Redis instance.

**gRPC**: mocked with Mox. The pattern:

1. In `test/test_helper.exs`, declare a mock for every gRPC service using the protobuf-generated `Service` module as the behaviour:

```elixir
Mox.defmock(SimOrchestrator.Mocks.GRPC, for: GRPCClient)
Mox.defmock(SimOrchestrator.Mocks.ECSIMService, for: CPSIM.GRPC.SimOrchestrator.ECSIM.Service)
```

2. In `test/support/helpers/grpc.ex`, provide a `mock_grpc_chan/1` helper that stubs the channel pool:

```elixir
def mock_grpc_chan(count \\ 1) do
  SimOrchestrator.Mocks.GRPC
  |> stub(:child_spec, fn _opts -> %{id: SimOrchestrator.Mocks.GRPC, start: {Kernel, :., [fn -> :ignore end, []]}} end)
  |> expect(:with_chan, count, fn _service_atom, callback -> callback.(%GRPC.Channel{}) end)
end
```

3. In each test file, call `mock_grpc_chan()` in `setup` and set expectations per RPC method. Encode/decode the response through protobuf to catch serialization bugs:

```elixir
setup :verify_on_exit!
setup do: mock_grpc_chan()

defp mock_ecsim_call(response, action) do
  actual_response =
    response
    |> response.__struct__.encode()
    |> response.__struct__.decode()

  expect(SimOrchestrator.Mocks.ECSIMService, action, fn _chan, request ->
    decoded = request |> request.__struct__.encode() |> request.__struct__.decode()
    assert decoded == request
    {:ok, actual_response}
  end)
end
```

**Other dependencies** (k8s client, external HTTP): Mox when a behaviour exists, manual stub module when not.

## Set-theoretic type warnings (Elixir 1.18+)

The compiler's "this clause is never used" / "clause will never match" warnings are inferred from types and are sometimes **optimistic** — they can flag a clause the type system believes is unreachable even though it is reachable at runtime.

**Do NOT remove a compiler-flagged "unreachable" fallback clause when the matched argument is a plain map** (e.g. an Ecto `field :x, :map` that defaults to `%{}`, or any value that can lack keys at runtime). The compiler may have inferred the value as a validated/closed-map shape, but the default/unvalidated path can still hit the fallback — removing it converts a graceful error tuple into a `FunctionClauseError`. Keep the fallback; leave the warning.

**Only remove an "unreachable" clause when the input is a type-guaranteed struct** (`%Call{}`, `%State{}`, `%Action16{}`, …) where the preceding clause provably matches every value of that struct type, or when matching on a fully type-determined internal function return (a `@spec`'d helper whose return union genuinely excludes the shape). External/loosely-typed data (plain maps, decoded JSON, params) keeps its defensive fallbacks.

When in doubt, verify the *actual* runtime type of the matched value (trace where it's built, check the schema field type) before deleting — never trust the "unreachable" claim at face value for non-struct inputs.

## Authorization scopes: never implement speculatively

Do not add a Scope (or any authorization-boundary protocol impl) for a model that has no
user-facing read path "for completeness". A pass-through/global impl gives a fake sense of
scoping: the day someone adds a user-facing list, it silently returns EVERYTHING instead of
failing loudly on the missing impl. Absence is the safety mechanism — implement a scope only
when a real read path needs it, with the actual scoping rule that path requires. Admin-only
internal reads go through explicit workflow functions instead.

## Ecto: no defaults unless they really make sense

Do not set `default:` on migration columns or schema fields as a reflex. Required fields are
`null: false` in the migration + `validate_required` in the changeset, and every writer supplies
the value explicitly (changeset cast/put_change, seeds, etc.). A default is justified only when it
genuinely models the domain — not to make inserts pass or to mirror a client-side convenience
default. This keeps the write contract explicit: what's in the row is exactly what a writer sent.

## Time

Compare times with `DateTime`: build instants with `DateTime.utc_now/0` / `DateTime.add/3` and compare with `DateTime.compare/2` — never raw `System.monotonic_time` arithmetic for deadlines/expiries, and never `<`/`>` operators on `DateTime` structs (term comparison, not chronological). Expiries anchored to real-world validity (signed URLs, tokens, sessions) are wall-clock instants — store and compare them as `DateTime`.

## Comments

Default: no comments. Add only when the **why** is non-obvious — hidden constraint, subtle invariant, workaround for a specific bug, behavior that would surprise a reader. If removing the comment would not confuse a future reader, do not write it.

Do NOT reference:
- The current task/PR/phase (`# Phase 2:`, `# Part of XYZ refactor`) — meaningful only in conversation, rots in code.
- Specific commit SHAs (`# Added in 030db807`) — Git history is authoritative.
- Specific callers (`# Called by RunController.foo`) — grep is authoritative and the reference will go stale.
- Incidental tool/vendor names the reader has no context for (`# talks to MinIO`, `# backed by hackney`) — name the role (object storage, HTTP client), not the brand, and only when it serves the *why*. Same for moduledocs and config comments: don't pad them with implementation/infra detail that isn't relevant to using the module.

Do NOT explain WHAT the code does — well-named identifiers already do that. Comments are for the WHY.
