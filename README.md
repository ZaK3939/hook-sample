# Foundry Template [![Github Actions][gha-badge]][gha] [![Foundry][foundry-badge]][foundry] [![License: MIT][license-badge]][license]

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg
[license]: https://opensource.org/licenses/MIT
[license-badge]: https://img.shields.io/badge/License-MIT-blue.svg

> [!WARNING] This is **experimental software** and is provided on an "as is" and "as available" basis. We **do not give
> any warranties** and **will not be liable for any losses** incurred through any use of this code base.

## Getting Started

```sh
$ forge init --template PaulRBerg/foundry-template my-project
$ cd my-project
$ bun install # install Solhint, Prettier, and other Node.js deps
$ forge install OpenZeppelin/uniswap-hooks --no-commit
$ forge install https://github.com/Uniswap/v4-periphery --no-commit
$ Add @openzeppelin/uniswap-hooks/=lib/uniswap-hooks/src/ in remappings.txt.
$ forge script script/HookMining.s.sol:DeployHookScript --rpc-url sepolia --broadcast --verify --legacy --ffi
```

## Related Efforts

- [foundry-rs/forge-template](https://github.com/foundry-rs/forge-template)
- [uniswap-hooks](https://github.com/OpenZeppelin/uniswap-hooks/)
- [v4-sepolia-deploy](https://github.com/haardikk21/v4-sepolia-deploy/)

## License

This project is licensed under MIT.
