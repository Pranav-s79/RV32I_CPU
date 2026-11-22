# Phase 2 Decisions

Record student-approved architectural decisions here. Do not treat recommendations in the guide as decisions until the student chooses them.

## Open questions

1. In which stage should branch and jump targets resolve? EX is the conventional starting point; earlier resolution can reduce redirect penalty but may add logic to ID.
2. Will the first pipeline keep the existing combinational memory interfaces, or introduce a request/response or registered-read contract? The latter is needed to use FPGA block RAM naturally, but it changes stall and stage timing.
3. Which retirement fields will the comparison harness use? At minimum it should capture PC and instruction, register writes, and committed store address/data/byte enables.
4. What reset/flush convention will be used for pipeline valid bits?

No Phase 2 architectural decisions have been made yet.
