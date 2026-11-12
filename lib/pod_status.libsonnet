// Imported by alerts and lib; never import those back.
{
  phase:: {
    pending: '1',
    running: '2',
    succeeded: '3',
    failed: '4',
    unknown: '5',
  },

  reason:: {
    evicted: '1',
    nodeAffinity: '2',
    nodeLost: '3',
    shutdown: '4',
    unexpectedAdmissionError: '5',
    unknown: '6',
  },
}
