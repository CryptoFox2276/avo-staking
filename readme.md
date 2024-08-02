# Get started
This staking contract allow users to stake token and earn AVO token as reward.

## Set environment for hardhat
In the `.env` file

- API_KEY:  API Key of Arbitrum mainnet

- PV_KEY: Private key of owner wallet

If you don't have api key, see [this](https://docs.arbiscan.io/getting-started/viewing-api-usage-statistics#creating-an-api-key) to create new API key

## Install project

```
    npm install
```
or
```
    yarn install
```

## Run hardhat node
```
    npx hardhat node
```

## Test
```
    npx hardhat test
```

## Deploy

- hardhat
```
    npx hardhat run scripts/deploy.js --network localhost
```
- Arbitrum One mainnet
```
    npx hardhat run scripts/deploy.js --network arbitrumOne
```
- Arbitrum Sepolia testnet
```
    npx hardhat run scripts/deploy.js --network arbitrumSepolia
```


## * Requirement
• стейкинг токена AVO, доходность зависит от срока стейкинга (месяц, 3 месяца, 6 месяцев, 12 месяцев) и от количества рефералов 1 и 2 уровня, чем их больше, тем выше доходность стейкинга, однако, максимальный APY который может получить пользователь это 60%.

• возможность партнёрского стейкинга по аналогии с проектом daomars.com , где пользователь стейкает токен проекта партнера а доходность получает в токенах AVO. (Т.е. возможность стекать партнерские токены)
