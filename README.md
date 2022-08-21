# neotest-vitest

This plugin provides a [Vitest](https://vitest.dev/) adapter for the [Neotest](https://github.com/rcarriga/neotest) framework.

All credits to [neotest-jest](https://github.com/haydenmeade/neotest-jest)

## Known issues
- Wrong error location on collecting results - (this is related to Vitest reporting issue)
- test.each is currently not well supported
- Weird behaviors when either neotest-jest is installed at same time (they share same test parsing logic)

## How to install it
```
use({
  'rcarriga/neotest',
  requires = {
    ...,
    'marilari88/neotest-vitest',
  }
  config = function()
    require('neotest').setup({
      ...,
      adapters = {
        require('neotest-jest') 
        }
    })
  end
})
```

## Usage

See neotest's documentation for more information on how to run tests.

## :gift: Contributing

Please raise a PR if you are interested in adding new functionality or fixing any bugs. When submitting a bug, please include an example spec that can be tested.

To trigger the tests for the adapter, run:

```sh
./scripts/test
```

## Bug Reports

Please file any bug reports and I _might_ take a look if time permits otherwise please submit a PR, this plugin is intended to be by the community for the community.
