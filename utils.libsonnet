{
  // Helper functions

  // objectHasObject returns true if o1 contains all kv pairs in o2
  // o1 may have more kv's than o2
  // extension of std.objectHas() functions
  // FIXME: only compares one level deep
  objectHasObject(o1, o2)::
    local matchedKeys = [
      k
      for k in std.objectFields(o2)  // for each key
      if std.objectHas(o1, k)  // check if key exists (prevent missing key error)
      if o1[k] == o2[k]  // compare key's value is equal
    ];
    // confirm all keys were matched
    if std.objectFields(o2) == matchedKeys then true else false,

  // stageMatrixPreviousElement recursively crawls backwards through our app's
  // global stageRefIds 'map of map of arrays' until if finds preceding
  // stages, if any.
  // Before it can walk the stageRefIds it needs to convert it to a matrix.
  // stageMatrixPreviousElement assumes stage (stageOrder) is an integer.
  // jsonnet keys must be a string so we convert int to string as required.
  // If we can change structure of $.p.stageRefIds then perhaps the matrix &
  // type conversion will no longer be necessary.
  // Structure refresher: we might have 2 stageBlocks with 3 stages each,
  // $._config.stageBlockOrdering: ['stg', 'prd'],
  // $.p.stageRefIds: {
  //   prd: { '1': [<stages>] , '2': [<stages>], '3': [<stages>]},
  //   stg: { '1': [<stages>] , '2': [<stages>], '3': [<stages>]},
  // }
  stageMatrixPreviousElement(mma, stageBlockOrder, stageBlock, stage)::
    // convert our $.p.stageRefIds 'map of map of arrays' to a matrix (2d array)
    // so we can index into and walk
    local stageMatrix = {} + {
      [stageBlock]+: std.objectFields(mma[stageBlock])
      for stageBlock in std.objectFields(mma)
    };

    // mma's stageBlock's must be member of stageBlockOrder array, else order indeterminable
    /*
    assert (std.length(
              std.setDiff(stageBlockOrder, std.objectFields(stageMatrix))
            ) > 0) :
           "stageBlock's found that aren't defined in stageBlockOrder, unable to determine stage order.";
    */
    // current positions
    local sPos = std.find(std.toString(stage), stageMatrix[stageBlock])[0];
    local bPos = std.find(stageBlock, stageBlockOrder)[0];

    // If at first stage in a stageBlock then preceding stages are either
    // non-existant or last in previous stageBlock
    if (sPos == 0) && (bPos == 0) then []  // first stage in first stageBlock has no preceding stages.
    else if (sPos == 0) && (bPos != 0) then  // first stage in second+ stageBlock
      // FIXME: This code assumes that previous stageBlock has stages, if it doesn't jsonnet won't compile
      // FIXME: Workaround this by specifying custom $._config.stageBlockOrdering in your app
      local prevSB = stageBlockOrder[bPos - 1];
      local prevSBlen = std.length(stageMatrix[prevSB]);
      local prevSBlastStage = stageMatrix[prevSB][prevSBlen - 1];
      mma[prevSB][prevSBlastStage]  // last stage in previous stageBlock

    // second+ stage so return previous stage's value(array)
    else
      local precedingPos = stageMatrix[stageBlock][sPos - 1];
      mma[stageBlock][precedingPos],
}
