local utils = import '../utils.libsonnet';

local test =
  {
    _config:: {
      mma+: {
        // l1
        stg+: {
          // l2
          '1': ['stg-1-a'],
          '2': ['stg-2-a'],
          '4': ['stg-4-a'],
        },
        prd+: {
          '1': ['prd-1-a'],
          '2': ['prd-2-a'],
        },
      },
      stageBlockOrder: ['stg', 'prd'],
    },
  };
{
  assert utils.stageMatrixPreviousElement(test._config.mma, test._config.stageBlockOrder, 'stg', 1) == [] : 'incorrect preceding array element return',
  assert utils.stageMatrixPreviousElement(test._config.mma, test._config.stageBlockOrder, 'stg', 4) == ['stg-2-a'] : 'incorrect preceding array element return',
  assert utils.stageMatrixPreviousElement(test._config.mma, test._config.stageBlockOrder, 'prd', 1) == ['stg-4-a'] : 'incorrect preceding array element return',
}
