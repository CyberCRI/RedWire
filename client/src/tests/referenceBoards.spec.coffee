EMPTY_DO_IN_PARALLEL_SOURCE =
  children: []
  process: "doInParallel"

EMPTY_DO_IN_PARALLEL_CONVERTED =
  data: "Do In Parallel"
  state: "open"
  metadata:
    source : EMPTY_DO_IN_PARALLEL_SOURCE

EMPTY_DO_IN_SEQUENCE_SOURCE =
  children: []
  process: "doInSequence"

EMPTY_DO_IN_SEQUENCE_CONVERTED =
  data: "Do In Sequence"
  state: "open"
  metadata:
    source: EMPTY_DO_IN_SEQUENCE_SOURCE

SINGLE_CHILD_SOURCE =
  children: [EMPTY_DO_IN_PARALLEL_SOURCE]
  process: "doInSequence"

SINGLE_CHILD_CONVERTED =
  data: "Do In Sequence"
  state: "open"
  metadata:
    source: SINGLE_CHILD_SOURCE

MULTIPLE_CHILDREN_SOURCE =
  children: [EMPTY_DO_IN_PARALLEL_SOURCE, EMPTY_DO_IN_SEQUENCE_SOURCE]
  process: "doInSequence"

MULTIPLE_CHILDREN_CONVERTED =
  data: "Do In Sequence"
  state: "open"
  metadata:
    source: MULTIPLE_CHILDREN_SOURCE

DEEP_SOURCE =
  children: [MULTIPLE_CHILDREN_SOURCE]
  process: "doInParallel"

DEEP_CONVERTED =
  data: "Do In Sequence"
  state: "open"
  metadata:
    source: DEEP_SOURCE


@.referenceBoards =

  EMPTY_DO_IN_PARALLEL:
    source: EMPTY_DO_IN_PARALLEL_SOURCE
    converted: EMPTY_DO_IN_PARALLEL_CONVERTED

  EMPTY_DO_IN_SEQUENCE:
    source: EMPTY_DO_IN_SEQUENCE_SOURCE
    converted: EMPTY_DO_IN_SEQUENCE_CONVERTED

  SINGLE_CHILD:
    source: SINGLE_CHILD_SOURCE
    converted: SINGLE_CHILD_CONVERTED

  MULTIPLE_CHILDREN:
    source: MULTIPLE_CHILDREN_SOURCE
    converted: MULTIPLE_CHILDREN_CONVERTED

  DEEP:
    source: DEEP_SOURCE
    converted: DEEP_CONVERTED