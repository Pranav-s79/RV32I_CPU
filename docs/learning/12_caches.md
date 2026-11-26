# 12. Caches and the Memory Hierarchy

## Locality

Programs tend to reuse recently accessed instructions/data (**temporal
locality**) and nearby addresses (**spatial locality**). A cache stores copies
of recently used memory blocks close to the processor to reduce average access
time.

The instruction cache (I-cache) serves fetches; the data cache (D-cache) serves
loads and stores. They can be separate or unified. This project guide proposes
separate caches after the pipeline and verification are stable.

## Address fields

A byte address is divided into:

- **byte offset:** which byte within a line;
- **index:** which cache set/line to inspect;
- **tag:** which memory region is stored there.

For a direct-mapped cache with `N` lines and a `2^k`-byte line, the index uses
`log2(N)` bits and the offset uses `k` bits. Remaining high bits are the tag.
Each line stores data, tag, and a valid bit.

## Hit and miss

A **hit** occurs when the selected line is valid and its tag matches. A **miss**
requires fetching a line from lower-level memory. A miss-handling state machine
must hold the requesting pipeline operation, wait for the response, fill the
line, then resume without duplicating a write or losing a request.

Measure hit rate, miss rate, and miss-stall cycles. A larger cache can reduce
misses while consuming more BRAM/LUTs, increasing access delay, or reducing
Fmax.

## Data-cache write policies

- **Write-through:** update lower memory on each store. Simpler consistency,
  but every store uses the memory path.
- **Write-back:** mark a line dirty and write it to lower memory when evicted.
  Fewer external writes but more state and a dirty-victim sequence.
- **Write-allocate:** bring a missed store's line into cache, then update it.
- **No-write-allocate:** send a missed store directly to lower memory.

Choose and document a policy before implementation. Byte strobes and partial
stores must remain correct for every lane.

## Memory latency and protocol separation

Keep the core's request/response contract separate from AXI details. A cache
or memory subsystem can translate simple core requests into lower-level bus
transactions. Simulation should be able to vary memory latency to expose
stall-handling bugs. Start with a simple memory model; add bus complexity only
when the CPU and cache behavior are correct.

## Check your understanding

1. Why do caches fetch a whole line instead of just one byte?
2. What does the valid bit prevent?
3. How do write-through and write-back differ on a store hit?
4. What must happen to the core request during a cache miss?

## In this repository

Caches are a later roadmap phase. See the interface and memory-map decisions in
[`../architecture.md`](../architecture.md), plus the later roadmap in
[`../../README.md`](../../README.md).
