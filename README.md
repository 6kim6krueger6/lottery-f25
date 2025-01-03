# Foundry Lottery 🎲

### Описание проекта
Foundry Lottery — это смарт-контрактная лотерея, построенная с использованием Solidity и тестируемая с помощью Foundry. Проект демонстрирует, как можно интегрировать Chainlink VRF для генерации случайных чисел.

---

### Основные функции
- Вход в лотерею с оплатой фиксированного взноса
- Генерация случайных чисел с использованием Chainlink VRF
- Выплата выигрыша победителю
- Автоматическое определение победителя после заданного интервала

---

### Как развернуть проект

#### 1. Установка зависимостей
Убедись, что у тебя установлены следующие инструменты:
- [Foundry](https://book.getfoundry.sh/getting-started/installation.html)
- Git
- Node.js

```bash
# Установка Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

#### 2. Клонирование репозитория
```bash
git clone https://github.com/6kim6krueger6/foundry-test.git
cd foundry-test
```

#### 3. Запуск тестов
```bash
forge test
```

---

### Скрипты для взаимодействия с контрактами
Проект содержит несколько полезных скриптов для взаимодействия с контрактами:

- **DeployRaffle.s.sol** — скрипт для деплоя контракта лотереи
- **Interactions.s.sol** — скрипт для создания подписки, пополнения баланса и добавления потребителя Chainlink VRF

---

### Структура репозитория
- `src/` — исходные коды смарт-контрактов
- `script/` — скрипты для деплоя и взаимодействия с контрактами
- `test/` — модульные тесты для контрактов
- `lib/` — внешние библиотеки

---

### TODO
- [ ] Добавить интерфейс для взаимодействия с лотереей (например, через React или Vue.js)
- [ ] Настроить CI/CD для автоматического запуска тестов при коммитах
- [ ] Провести аудит безопасности смарт-контракта

---

### Файл контракта для тестов
```solidity
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../../script/Interactions.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract InteractionsTestRaffle is Test {
    Raffle raffle;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig config;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        helperConfig = new HelperConfig();
        (raffle, helperConfig) = deployRaffle.run();
        config = helperConfig.getConfig();
    }

    function testCreateSubscription() public {
        CreateSubscription createSubscription = new CreateSubscription();
        (uint256 subId,) = createSubscription.createSubscription(config.vrfCoordinator, config.account);
        assert(subId > 0);
    }

    function testFundSubscription() public {
        FundSubscription fundSubscription = new FundSubscription();
    }
}
```
