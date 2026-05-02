<div style="text-align: center;font-size: xxx-large" >Hypium</div>
<div style="text-align: center">A unit test framework for OpenHarmonyOS application</div>

## Hypium是什么?
***
- Hypium是OpenHarmony上的测试框架，提供单元测试用例执行能力，提供用例编写基础接口，生成对应报告，用于测试系统或应用接口。
- Hypium结构化模型：hypium工程工程主要由List.test.ets与TestCase.test.ets组成。
```
rootProject                  // Hypium工程根目录
├── moduleA
│   ├── src
│      ├── main                   // 被测试应用目录
│      ├── ohosTest               // 测试用例目录
│         ├── ets
│            └── test
│               └── List.test.ets      
│               └── TestCase.test.ets  
└── moduleB
    ...
│               └── List.test.ets      
│               └── TestCase.test.ets  
```

## 安装使用

- 方式一
```javascript
ohpm i @ohos/hypium
```
- 方式二
- 在DevEco Studio内使用Hypium
- 工程级oh-package.json5内配置:
```json
"dependencies": {
    "@ohos/hypium": "1.0.25"
}
```
注：
hypium服务于OpenHarmonyOS应用对外接口测试、系统对外接口测试（SDK中接口），完成HAP自动化测试。

## 引入方式
```javascript
import { describe, it, expect } from '@ohos/hypium';
```


## 功能特性

| No.  | 特性     | 功能说明                                              |
| ---- | -------- |---------------------------------------------------|
| 1    | 基础流程 | 支持编写及异步执行基础用例。                                    |
| 2    | 断言库   | 判断用例实际结果值与预期值是否相符。                                |
| 3    | 异步代码测试   | 等待异步任务完成之后再判断测试是否成功。                                |
| 4    | 公共能力   | 支持获取用例信息的基础能力以及日志打印、清除等能力。                                |
| 5    | Mock能力 | 支持函数级Mock能力，对定义的函数进行Mock后修改函数的行为，使其返回指定的值或者执行某种动作。 |
| 6    | 数据驱动 | 提供数据驱动能力，支持复用同一个测试脚本，使用不同输入数据驱动执行。                |
| 7    | 专项能力 | 支持筛选测试套/测试用例；支持配置跳过指定测试套/测试用例；支持配置超时时间；提供随机执行、压力测试、遇错即停等测试模式。     |

## 接口
### describe

describe(testSuiteName: string, func: Function): void

定义一个测试套。

**参数：**

| 参数名 | 类型     | 必填 | 说明                                  | 
| --- |--------|----|-------------------------------------|
| testSuiteName | string | 是  | 测试套的名称。                             |
| func | Function | 是  | 测试套函数，用于注册测试用例。**注意：测试套函数不支持异步函数。** |

**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default function assertCloseTest() {
    describe('assertClose', () => {
        it('assertClose_success', 0, () => {
            let a = 100;
            let b = 0.1;
            expect(a).assertClose(99, b);
        })
    })
}
```

### beforeAll

beforeAll(func: Function): void

在测试套内定义一个预置条件，在所有测试用例开始前执行且仅执行一次

**参数：**

| 参数名 | 类型     | 必填    | 说明                                                 | 
|------------| ------ |-------|----------------------------------------------------|
| func       | Function | 是     | 预置动作函数，在一组测试用例（测试套）开始执行之前执行。支持异步函数。 |

**示例：**
```javascript
import { beforeAll, describe, it, expect } from '@ohos/hypium';

export default function customAssertTest() {
    describe('customAssertTest', () => {
        beforeAll(() => {
            console.info('beforeAll')
        })
        it('assertClose_success', 0, () => {
            let a = 100;
            let b = 0.1;
            expect(a).assertClose(99, b);
        })
    })
}
```


### beforeEach

beforeEach(func: Function): void

在测试套内定义一个预置条件，在每条测试用例开始前执行，执行次数与it定义的测试用例数一致。

**参数：**

| 参数名 | 类型     | 必填    | 说明                                                  | 
|------------| ------ |-------|-----------------------------------------------------|
| func       | Function | 是     | 预置动作函数，在每条测试用例开始执行之前执行，支持异步函数。  |

**示例：**
```javascript
import { beforeEach, describe, it, expect } from '@ohos/hypium';

let str = "";

export default function test() {
    describe('test0', () => {
        beforeEach(() => {
            str += "A";
        })
        it('test0000', 0, () => {
            expect(str).assertEqual("A");
        })
    })
}
```

### afterEach

afterEach(func: Function): void

在测试套内定义一个清理函数，在每条测试用例结束后执行，执行次数与it定义的测试用例数一致。

**参数：**

| 参数名 | 类型     | 必填    | 说明                          | 
|------------| ------ |-------|-----------------------------|
| func       | Function | 是     | 清理动作函数，在每条测试用例执行完成后运行。支持异步函数。 |

**示例：**
```javascript
import { afterEach, describe, it, expect } from '@ohos/hypium';

let str = "B";

export default function test() {
    describe('test0', () => {
        afterEach(async () => {
            console.log(str); // BA
        })
        it('test0000', 0, () => {
            str += "A";
            expect(str).assertEqual("BA");
        })
    })
}
```

### beforeEachIt<sup>1.0.25</sup>

export function beforeEachIt(func: Function): void

在测试套内定义一个单元预置条件，在每条测试用例开始前执行。外层测试套定义的beforeEachIt会在内部测试套中的测试用例执行前执行。

**参数：**

| 参数名 | 类型     | 必填    | 说明                                                  | 
|------------| ------ |-------|-----------------------------------------------------|
| func       | Function | 是     | 预置动作函数，在每条测试用例开始执行之前执行，支持异步函数。  |

**示例：**

```javascript
import { afterEach, afterEachIt, beforeEach, beforeEachIt, describe, expect, it } from '@ohos/hypium';

let str = "";

export default function test() {
    describe('test0', () => {
        beforeEach(async () => {
            str += "A";
        })
        beforeEachIt(async () => {
            str += "B";
        })
        afterEach(async () => {
            str += "C";
        })
        afterEachIt(async () => {
            str += "D";
        })
        it('test0000', 0, () => {
            expect(str).assertEqual("BA");
        })
        describe('test1', () => {
            beforeEach(async () => {
                str += "E";
            })
            beforeEachIt(async () => {
                str += "F";
            })
            it('test1111', 0, async () => {
                expect(str).assertEqual("BACDBFE");
            })
        })
    })
}
```


### afterEachIt<sup>1.0.25</sup>

export function afterEachIt(func: Function): void

在测试套内定义一个单元预置条件，在每条测试用例结束后执行。外层测试套定义的afterEachIt会在内部测试套中的测试用例执行结束后执行。

**参数：**

| 参数名 | 类型     | 必填    | 说明                          | 
|------------| ------ |-------|-----------------------------|
| func       | Function | 是     | 清理动作函数，在每条测试用例执行完成后运行。支持异步函数。 |

**示例：**
```javascript
import { afterEach, afterEachIt, beforeEach, beforeEachIt, describe, expect, it } from '@ohos/hypium';

let str = "";

export default function test() {
    describe('test0', () => {
        beforeEach(async () => {
            str += "A";
        })
        beforeEachIt(async () => {
            str += "B";
        })
        afterEach(async () => {
            str += "C";
        })
        afterEachIt(async () => {
            str += "D";
        })
        it('test0000', 0, () => {
            expect(str).assertEqual("BA");
        })
        describe('test1', () => {
            beforeEach(async () => {
                str += "E";
            })
            beforeEachIt(async () => {
                str += "F";
            })
            it('test1111', 0, async () => {
                expect(str).assertEqual("BACDBFE");
            })
        })
    })
}
```

### afterAll

afterAll(func: Function): void

在测试套内定义一个清理函数，在所有测试用例结束后执行且仅执行一次。

**参数：**

| 参数名 | 类型     | 必填    | 说明                          | 
|------------| ------ |-------|-----------------------------|
| func       | Function | 是     | 清理动作函数，在一组测试用例（测试套）执行完成后运行，用于 释放资源、重置状态、清除数据。支持异步函数。 |

**示例：**
```javascript
import { afterAll, describe, it, expect, beforeEach, beforeEachIt, afterEach, afterEachIt, beforeAll } from '@ohos/hypium';

export default function customAssertTest() {
    describe('outerDescribe', () => {
        beforeAll(() => {
            console.info('beforeAll')
        })
        afterAll(() => {
            console.info('afterAll');
        })
        beforeEach(() => {
            console.info('outer beforeEach')
        })
        afterEach(() => {
            console.info('outer afterEach')
        })
        beforeEachIt(() => {
            console.info('outer beforeEachIt')
        })
        afterEachIt(() => {
            console.info('outer afterEachIt')
        })
        it('outer_it', 0, () => {
            console.info('outer it')
            let a = 100;
            let b = 0.1;
            expect(a).assertClose(99, b);
        })
        describe('innerDescribe', () => {
            beforeEach(() => {
                console.info('inner beforeEach')
            })
            afterEach(() => {
                console.info('inner afterEach')
            })
            beforeEachIt(() => {
                console.info('inner beforeEachIt')
            })
            afterEachIt(() => {
                console.info('inner afterEachIt')
            })
            it('innter_it', 0, () => {
                console.info('inner it')
                let a = 100;
                let b = 0.1;
                expect(a).assertClose(99, b);
            })
        })
    })
}
// 执行顺序
// beforeAll -> 
// outer beforeEachIt -> outer beforeEach -> outer it -> outer afterEach -> outer afterEachIt ->
// outer beforeEachIt -> inner beforeEachIt -> inner beforeEach -> inner it -> inner afterEach -> inner afterEachIt -> outer afterEachIt ->
// afterAll

// beforeEachIt在beforeEach前执行，afterEachIt在afterEach后执行
// 父测试套的beforeEachIt和afterEachIt会在子测试套中执行，且父测试套的beforeEachIt会在子测试套的beforeEachIt之前执行，父测试套的afterEachIt会在子测试套的afterEachIt之后执行
```

### beforeItSpecified<sup>1.0.15</sup>

`beforeItSpecified(testCaseNames: Array<string> | string, func: Function): void`

在测试套内定义一个预置条件，仅在指定测试用例开始前执行。

**参数：**

| 参数名 | 类型                      | 必填 | 说明 | 
|------------|-------------------------|----|----|
| testCaseNames   | `Array<string>` 或 string | 是  | 单个用例名称或用例名称数组。 |
|      func      | Function                | 是  |  预置动作函数，在自定义的一组测试用例或单个测试用例开始执行之前运行。支持异步函数。  |

**示例：**
```javascript
import { beforeItSpecified, describe, expect, it } from '@ohos/hypium';

export default function beforeItSpecifiedTest() {
    let a = 1;
    describe('beforeItSpecifiedTest', () => {
        beforeItSpecified(['String_assertContain_success'], () => {
            a++;
        })
        it('String_assertContain_success', 0, () => {
            expect(a).assertEqual(2);
        })
    })
}
```

### afterItSpecified<sup>1.0.15</sup>

`afterItSpecified(testCaseNames: Array<string> | string, func: Function): void`

在测试套内定义一个清理函数，仅在指定测试用例结束后执行。

**参数：**

| 参数名 | 类型                      | 必填 | 说明 | 
|------------|-------------------------|----|----|
| testCaseNames   | `Array<string>` 或 string | 是  | 单个用例名称或用例名称数组。|
|      func      | Function                | 是  |  清理动作函数，在自定义的一组测试用例或单个测试用例执行完成后运行。支持异步函数。 |


**示例：**
```javascript
import { afterItSpecified, describe, expect, it } from '@ohos/hypium';

export default function afterItSpecifiedTest() {
    describe('afterItSpecifiedTest', () => {
        let a = 1;
        afterItSpecified(['String_assertContain_success'], () => {
            expect(a).assertEqual(2);
        })
        it('String_assertContain_success', 0, () => {
            a++;
        })
    })
}
```

### it

it(testCaseName: string, attribute: number, func: Function): void

定义一条测试用例

**参数：**

| 参数名 | 类型                 | 必填 | 说明                               | 
|------------|--------------------|----|----------------------------------------------------|
| testSuiteName      | string             | 是  | 测试套的名称。 |
|      attribute    | number | 是  | 过滤参数，支持传0或Level、Size、TestType对象中的枚举值。若传0，则不过滤用例，若传其他参数，则可对用例的级别、规模、测试类型进行过滤，具体参见[TestType, Size, Level相关介绍](#testtype)。 |
|         func      |Function |  是  |        测试函数，用于注册测试用例。                                                          |

**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default function attributeTest() {
    describe('attributeTest', () => {
        it("testAttributeIt", 0, () => {
            let a = 1;
            expect(a).assertEqual(a);
        })
    })
}
```

### xdescribe<sup>1.0.17</sup>

xdescribe(testSuiteName: string, func: Function): void

跳过一个测试套。

**参数：**

| 参数名 | 类型     | 必填| 说明           | 
| --- | ------ |---|--------------|
| testSuiteName | string | 是 | 跳过的测试套名称。    |
| func | Function | 是 | 测试套函数，用于注册测试用例。**注意：测试套函数不支持异步函数。** |

**示例：**
```javascript
import { expect, xdescribe, xit } from '@ohos/hypium';

export default function skip1() {
    xdescribe('skip1', () => {
        xit('assertContain1', 0, () => {
            let a = true;
            let b = true;
            expect(a).assertEqual(b);
        })
    })
}
```

### xit<sup>1.0.17</sup>

xit(testCaseName: string,attribute: number,func: Function): void

跳过一条测试用例。

**参数：**

| 参数名 | 类型                | 必填 | 说明                                                                                            | 
|------------|-------------------|----|-----------------------------------------------------------------------------------------------|
| testSuiteName      | string   | 是  | 跳过的测试用例名称。                                                                                    |
|      attribute              | number| 是  | 过滤参数，支持传0或Level、Size、TestType对象中的枚举值。若传0，则不过滤用例，若传其他参数，则可对用例的级别、规模、测试类型进行过滤，具体参见[TestType, Size, Level相关介绍](#testtype) |
|         func                    |Function |  是  | 测试函数，用于注册测试用例。                                                                                |

**示例：**
```javascript
import { describe, expect, xit } from '@ohos/hypium';

export default function skip1() {
    describe('skip1', () => {
        xit('assertContain1', 0, () => {
            let a = true;
            let b = true;
            expect(a).assertEqual(b);
        })
    })
}
```

### expect

expect(actualValue?: any): Assert

支持bool类型判断等多种断言方法

**参数：**

| 参数名  | 类型          | 必填  | 说明                                                        |
|---|---|---|-----------------------------------------------------------|
| actualValue  | any      |  否 | 期望值，即待验证的表达式或变量的值。可为任意类型，包括基本类型、对象、函数或空值等。  |


**返回值：**

|类型   |说明   |
|---|---|
| Assert  |断言对象，提供一系列匹配器方法用于执行具体断言操作，详见[Assert](#assert)      |


**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default function expectTest() {
    describe('Expect', () => {
        it('expect_equalTo', 0, () => {
            let result = 2 + 3;
            expect(result).assertEqual(5); // 断言相等
        })

        it('expect_not_equalTo', 0, () => {
            let name = 'Tom';
            expect(name).assertNotEqual('Jerry'); // 断言不相等
        })
    })
}
```
### Assert

#### assertClose

assertClose(expectValue: number, precision: number): void

检验实际值和预期值的接近程度是否达到预期。

**参数：**

| 参数名  | 类型          | 必填 | 说明                                                      |
|---|---|----|---------------------------------------------------------|
| expectValue  | number         | 是  | 期望值，即预期的正确结果数值。                                         |
| precision  | number       | 是   | 精度值（容差范围，delta），表示允许的最大误差。期望值和实际值的差值除以实际值的结果小于精度值则验证通过。 |


**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default function assertTest() {
    describe('expectTest', () => {
        it('assertCloseTest', 0, () => {
            let a: number = 100;
            let b: number = 0.1;
            expect(a).assertClose(99, b);
        })
    })
}
```

#### assertContain

assertContain(expectValue: any): void

检验实际值中是否包含expectvalue，如：验证数组中是否包含某一个元素，或验证字符串中是否包含某一个子串。

**参数：**

| 参数名  | 类型          | 必填 | 说明                                                        |
|---|---|----|-----------------------------------------------------------|
| expectValue  | any   | 是  | 期望值，即待验证的表达式或变量的值。可为任意类型，包括基本类型、对象类型、空值等。  |


**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default assertContainTest() {
    describe('expectTest', () => {
        it('assertContain_1', 0, () => {
            let a = "abc";
            expect(a).assertContain('b');
        })
    })
}
```

#### assertEqual

assertEqual(expectValue: any): void

检验实际值是否等于expectvalue。

**参数：**

| 参数名  | 类型          | 必填 | 说明                                                        |
|---|---|----|-----------------------------------------------------------|
| expectValue  | any         | 是  |    期望值，即待验证的表达式或变量的值。可为任意类型，包括基本类型、对象类型或空值等。              |

**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default function assertEqualTest() {
    describe('expectTest', () => {
        it('assertEqualTest', 0, () => {
            expect(3).assertEqual(3);
        })
    })
}
```

#### assertFail

assertFail(): void

抛出一个错误。

**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default function assertFailTest() {
    describe('expectTest', () => {
        it('assertFailTest', 0, () => {
            expect().assertFail(); // 用例失败;
        })
    })
}
```
#### assertFalse

assertFalse(): void

检验实际值是否是false。

**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default function assertFalseTest() {
    describe('expectTest', () => {
        it('assertFalseTest', 0, () => {
            expect(false).assertFalse();
        })
    })
}
```

#### assertTrue

assertTrue(): void

检验实际值是否是true。

**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default function assertTrueTest() {
    describe('expectTest', () => {
        it('assertTrueTest', 0, () => {
            expect(true).assertTrue();
        })
    })
}

```

#### assertInstanceOf

assertInstanceOf(expectValue: string): void

检验实际值是否是expectvalue类型，支持基础类型。

**参数：**

| 参数名  | 类型          | 必填 | 说明               |
|---|---|----|------------------|
| expectValue  | string         | 是  | 期望类型，必须是一个字符串类型。 |

**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default function assertInstanceOfTest() {
    describe('expectTest', () => {
        it('assertInstanceOfTest', 0, () => {
            let a: string = 'strTest';
            expect(a).assertInstanceOf('String');
        })
    })
}

```

#### assertLarger

assertLarger(expectValue: number): void

检验实际值是否大于expectvalue。

**参数：**

| 参数名  | 类型     | 必填 | 说明               |
|---|--------|----|------------------|
| expectValue  | number | 是  | 期望值，参数必须是一个数字类型。 |

**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default function assertLargerTest() {
    describe('expectTest', () => {
        it('assertLargerTest', 0, () => {
            expect(3).assertLarger(2);
        })
    })
}
```

#### assertLess

assertLess(expectValue: number): void

检验实际值是否小于expectvalue。

**参数：**

| 参数名  | 类型     | 必填 | 说明               |
|---|--------|----|------------------|
| expectValue  | number | 是  | 期望值，参数必须是一个数字类型。 |


**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default function assertLessTest() {
    describe('expectTest', () => {
        it('assertLessTest', 0, () => {
            expect(2).assertLess(3);
        })
    })
}

```

#### assertNull

assertNull(): void

检验实际值是否是null。

**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default function assertNullTest() {
    describe('expectTest', () => {
        it('assertNullTest', 0, () => {
            expect(null).assertNull();
        })
    })
}
```

#### assertThrowError

assertThrowError(expectValue: string | Function): void

检验actualvalue抛出Error的message是否是expectValue，或者抛出的Error的类是否是expectValue。使用此断言时，actualvalue必须是一个函数。

**参数：**

| 参数名  | 类型                | 必填 | 说明                       |
|---|-------------------|----|--------------------------|
| expectValue  | string 或 function | 是  | 期望值，参数必须是一个字符串类型或者函数。 |


**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default function assertThrowErrorTest() {
    describe('expectTest', () => {
        it('assertThrowErrorTest', 0, () => {
            expect(() => {
                throw new Error('test');
            }).assertThrowError('test');
        })
        it('assertThrowErrorTypeTest', 0, () => {
            expect(() => {
                throw new TypeError('test');
            }).assertThrowError(TypeError);
        })
    })
}

```

#### assertUndefined

assertUndefined(): void

检验实际值是否是undefined。

**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default function assertUndefinedTest() {
    describe('expectTest', () => {
        it('assertUndefinedTest', 0, () => {
            expect(undefined).assertUndefined();
        })
    })
}

```

#### assertNaN<sup>1.0.4<sup>

assertNaN(): void

检验实际值是否是一个NaN。

**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default function assertNaNTest() {
    describe('expectTest', () => {
        it('assertNaNTest', 0, () => {
            expect(Number.NaN).assertNaN(); // true
        })
    })
}
```

#### assertNegUnlimited<sup>1.0.4<sup>

assertNegUnlimited(): void

检验实际值是否等于Number.NEGATIVE_INFINITY。

**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default function assertNegUnlimitedTest() {
    describe('expectTest', () => {
        it('assertNegUnlimitedTest', 0, () => {
            expect(Number.NEGATIVE_INFINITY).assertNegUnlimited(); // true
        })
    })
}
```

#### assertPosUnlimited<sup>1.0.4<sup>

assertPosUnlimited(): void

检验实际值是否等于Number.POSITIVE_INFINITY。

**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default function assertPosUnlimitedTest() {
    describe('expectTest', () => {
        it('assertPosUnlimitedTest', 0, () => {
            expect(Number.POSITIVE_INFINITY).assertPosUnlimited(); // true
        })
    })
}
```

#### assertDeepEquals<sup>1.0.4<sup>

assertDeepEquals(expectValue: any): void

检验实际值和expectvalue是否完全相等，用于对对象类型进行值相等的判断。

**参数：**

| 参数名  | 类型              | 必填 | 说明                                         |
|---|-----------------|----|--------------------------------------------|
| expectValue  | any | 是  | 期望值，即待验证的表达式或变量的值。可为任意类型，包括基本类型、对象类型或空值等。  |


**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default function assertDeepEqualsTest() {
    describe('expectTest', () => {
        it('deepEquals_array_not_have_true', 0, () => {
            const a: Array<number> = [];
            const b: Array<number> = [];
            expect(a).assertDeepEquals(b);
        })
    })
}
```

#### assertPromiseIsPending<sup>1.0.4<sup>

assertPromiseIsPending(): Promise<void>

判断实际值中的Promise是否处于Pending状态。


**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default function assertPromiseIsPendingTest() {
    describe('expectTest', () => {
        it('assertPromiseIsPendingTest', 0, async () => {
            let p: Promise<void> = new Promise<void>(() => {});
            await expect(p).assertPromiseIsPending(); // 返回Promise<void>类型，注意在异步函数中调用
        })
    })
}
```

#### assertPromiseIsRejected<sup>1.0.4<sup>

assertPromiseIsRejected(): Promise<void>

判断promise是否处于Rejected状态。


**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

interface PromiseInfo {
  res: string;
}

export default function assertPromiseIsRejectedTest() {
    describe('expectTest', () => {
        it('assertPromiseIsRejectedTest', 0, async () => {
            let info: PromiseInfo = {res: "no"};
            let p: Promise<PromiseInfo> = Promise.reject(info);
            await expect(p).assertPromiseIsRejected(); // 返回Promise<void>类型，注意在异步函数中调用
        })
    })
}

```

#### assertPromiseIsRejectedWith<sup>1.0.4<sup>

assertPromiseIsRejectedWith(expectValue: any): Promise<void>

判断promise是否处于Rejected状态，并且比较抛出的Reject内容和预期值是否值相等。


**参数：**

| 参数名  | 类型              | 必填 | 说明                                         |
|---|-----------------|----|--------------------------------------------|
| expectValue  | any | 是  | 期望Promise抛出的Reject内容。可为任意类型，包括基本类型、对象、函数等。  |


**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

interface PromiseInfo {
  res: string;
}

export default function assertPromiseIsRejectedWithTest() {
    describe('expectTest', () => {
        it('assertPromiseIsRejectedWithTest', 0, async () => {
            let info: PromiseInfo = { res: "reject value" };
            let p: Promise<PromiseInfo> = Promise.reject(info);
            await expect(p).assertPromiseIsRejectedWith(info); // 返回Promise<void>类型，注意在异步函数中调用
        })
    })
}
```



#### assertPromiseIsRejectedWithError<sup>1.0.4<sup>

assertPromiseIsRejectedWithError(expectedErrorType: Function | string, expectedErrorMessage?: string): Promise<void>

判断promise是否处于Rejected状态并有异常，同时可以比较异常的类型和message值。只传一个参数时，可以校验Reject抛出的错误的类型或是message是否符合预期；传两个参数时，校验Reject抛出的错误的类型和message都符合预期。

**参数：**

| 参数名  | 类型              | 必填 | 说明                                         |
|---|-----------------|----|--------------------------------------------|
| expectedErrorType  | Function 或 strinng | 是  | 期望Promise抛出的Reject错误的类型或是message。  |
| expectedErrorMessage  | string | 否  | 期望Promise抛出的Reject错误的message。  |


**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default function assertPromiseIsRejectedWithErrorTest() {
    describe('expectTest', () => {
        it('assertPromiseIsRejectedWithErrorTest', 0, async () => {
            let p1: Promise<TypeError> = Promise.reject(new TypeError('number'));
            await expect(p1).assertPromiseIsRejectedWithError(TypeError, 'number'); // 返回Promise<void>类型，注意在异步函数中调用
        })
    })
}

```

#### assertPromiseIsResolved<sup>1.0.4<sup>

assertPromiseIsResolved(): Promise<void>

判断promise是否处于Resolved状态。


**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

interface PromiseInfo {
  res: string;
}

export default function assertPromiseIsResolvedTest() {
    describe('expectTest', () => {
        it('assertPromiseIsResolvedTest', 0, async () => {
            let info: PromiseInfo = { res: "result value" };
            let p: Promise<PromiseInfo> = Promise.resolve(info);
            await expect(p).assertPromiseIsResolved(); // 返回Promise<void>类型，注意在异步函数中调用
        })
    })
}
```



#### assertPromiseIsResolvedWith<sup>1.0.4<sup>

assertPromiseIsResolvedWith(expectValue: any): Promise<void>

判断promise是否处于Resolved状态，并且比较执行的结果值。

**参数：**

| 参数名  | 类型              | 必填 | 说明                         |
|---|-----------------|----|----------------------------|
| expectValue  | any | 是  | 期望promise函数在Resolved后返回的值。 |


**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

interface PromiseInfo {
  res: string;
}

export default function assertPromiseIsResolvedWithTest() {
    describe('expectTest', ()=> {
        it('assertPromiseIsResolvedWithTest', 0, async () => {
            let info: PromiseInfo = {res: "result value"};
            let p: Promise<PromiseInfo> = Promise.resolve(info);
            await expect(p).assertPromiseIsResolvedWith(info); // 返回Promise<void>类型，注意在异步函数中调用
        })
    })
}

```

#### not<sup>1.0.4<sup>

not(): Assert

对断言结果取反，支持所有的Assert断言功能。


**返回值：**

| 类型             | 说明                                        |
|----------------|-------------------------------------------|
| Assert	 | 断言对象，提供一系列匹配器方法用于执行具体断言操作，详见[Assert](#assert)|


**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default function assertNotTest() {
    describe('assertNot', () => {
        it('assertNot001', 0, () => {
            expect(1).not().assertLargerOrEqual(2);
        })
    })
}
```

#### message<sup>1.0.17<sup>

message(msg: string): Assert

自定义断言异常信息。

**参数：**

| 参数名  | 类型              | 必填 | 说明               |
|---|-----------------|----|------------------|
| msg  | string | 是  | 设置断言失败时的自定义错误消息。 |


**返回值：**

| 类型             | 说明                                        |
|----------------|-------------------------------------------|
| Assert	 | 断言对象，提供一系列匹配器方法用于执行具体断言操作，详见[Assert](#assert)|

**示例：**
```javascript
import { describe, expect, it } from '@ohos/hypium';

export default function assertMessageTest() {
    describe('assertMessage', () => {
        it('assertMessage001', 0, () => {
            let actualValue = 0;
            let expectValue = 2;
            expect(actualValue).message('0 != 2').assertEqual(expectValue);
        })
    })
}

```

### SysTestKit

#### existKeyword

existKeyword(keyword: string, timeout: number): boolean

检测hilog日志中是否打印，仅支持检测单行日志。若指定时间内找到指定的日志关键字，则返回true，否则返回false。

**参数：**

| 参数名  | 类型     | 必填 | 说明              |
|---|--------|----|-----------------|
| keyword  | string | 是  | 待查找关键字。         |
| timeout     | number | 否  | 设置的查找时间，单位秒（s），默认值4s。 |

**返回值：**

| 类型             | 说明                          |
|----------------|-----------------------------|
| boolean	 | 查找字段是否存在，true：存在；false：不存在。 |


**示例：**
```javascript
import { describe, expect, it, Level, Size, SysTestKit, TestType } from '@ohos/hypium';
import hilog from '@ohos.hilog';

const domain = 0;
const tag = 'SysTestKitTest';

function logTest() {
    hilog.info(domain, 'test', `logTest called selfTest`);
}

export default function abilityTest() {
    describe('SysTestKitTest', () => {

        it("testExistKeyword", TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL0, async () => {
            await SysTestKit.clearLog();
            hilog.debug(domain, tag, `testExistKeyword start `);
            logTest();
            const isCalled = await SysTestKit.existKeyword('logTest');
            hilog.debug(domain, tag, `testExistKeyword isCalled, ${isCalled} `);
            expect(isCalled).assertTrue();
            hilog.debug(domain, tag, `testExistKeyword end`);
        })
    })
}
```


#### actionStart

actionStart(tag: string): void

添加用例执行过程打印自定义日志

**参数：**

| 参数名  | 类型     | 必填 | 说明       |
|---|--------|----|----------|
| tag  | string | 是  | 自定义日志信息。 |

**示例：**
```javascript
import { describe, expect, it, SysTestKit } from '@ohos/hypium';

export default function actionTest() {
    describe('actionTest', () => {
        it('existKeyword', 0, () => {
            let tag = '[MyTest]';
            SysTestKit.actionStart(tag);
            //do something
        })
    })
}
```

#### actionEnd

actionEnd(tag: string): void

添加用例执行过程打印自定义日志。

**参数：**

| 参数名  | 类型     | 必填 | 说明       |
|---|--------|----|----------|
| tag  | string | 是  | 自定义日志信息。 |

**示例：**
```javascript
import { describe, expect, it, SysTestKit } from '@ohos/hypium';

export default function actionTest() {
    describe('actionTest', () => {
        it('existKeyword', 0, async () => {
            let tag = '[MyTest]';
            //do something
            SysTestKit.actionEnd(tag);
        })
    })
}
```

#### getDescribeName

getDescribeName(): string

获取当前测试用例所属的测试套名称。

**返回值：**

| 类型             | 说明          |
|----------------|-------------|
| string	 | 返回当前测试套的名称。 |

**示例：**
```javascript
import { describe, expect, it, SysTestKit } from '@ohos/hypium';

export default function actionTest() {
    describe('SysTestKitTest', () => {
        it("testGetDescribeName", 0, () => {
            const describeName = SysTestKit.getDescribeName();
            expect(describeName).assertEqual('SysTestKitTest');
        })
    })
}
```

#### getItName

getItName(): string

获取当前测试用例的名称。

**返回值：**

| 类型             | 说明           |
|----------------|--------------|
| string	 | 返回当前测试用例的名称。 |

**示例：**
```javascript
import { describe, expect, it, SysTestKit } from '@ohos/hypium';

export default function actionTest() {
    describe('SysTestKitTest', () => {

        it("testGetItName", 0, () => {
            const itName = SysTestKit.getItName();
            expect(itName).assertEqual('testGetItName');
        })
    })
}
```

#### getItAttribute

getItAttribute(): number

获取当前测试用例的过滤参数。

**返回值：**

| 类型             | 说明                      |
|----------------|-------------------------|
| number	 | 返回当前测试用例的级别、规划、类型等过滤参数。 |

**示例：**
```javascript
import { describe, expect, it, Level, Size, SysTestKit, TestType } from '@ohos/hypium';

export default function abilityTest() {
    describe('SysTestKitTest', () => {

        it("testGetItAttribute", TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL0, () => {
            const testType: TestType | Size | Level = SysTestKit.getItAttribute();
            expect(testType).assertEqual(TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL0);
        })
    })
}
```

### MockKit

#### mockFunc

mockFunc(obj: Object, func: Function): Function

Mock某个类的实例上的公共方法，支持使用异步函数

**参数：**

| 参数名    | 类型   | 必填 | 说明          |
|--------|------|----|-------------|
| Object | obj | 是  | 某个类的实例。     |
| Function |func  | 是  | 类的实例上的公共方法。 |


**返回值：**

| 类型             | 说明                            |
|----------------|-------------------------------|
| Function	 | 返回被Mock的函数。结合[when](#when)使用。 |

**示例：**
```javascript
import { describe, expect, it, MockKit, when } from '@ohos/hypium';

class ClassName {
    constructor() {
    }

    method_1(arg: string) {
       return '888888';
    }
}

export default function afterReturnTest() {
    describe('afterReturnTest', () => {
        it('afterReturnTest', 0, () => {
            console.info("it1 begin");
            // 1.创建一个Mock能力的对象MockKit
            let mocker: MockKit = new MockKit();
            // 2.定类ClassName，里面两个函数，然后创建一个对象claser
            let claser: ClassName = new ClassName();
            // 3.进行Mock操作,比如需要对ClassName类的method_1函数进行Mock
            let mockfunc: Function = mocker.mockFunc(claser, claser.method_1);
            // 4.期望claser.method_1函数被Mock后, 以'test'为入参时调用函数返回结果'1'
            when(mockfunc)('test').afterReturn('1');
            // 5.对Mock后的函数进行断言，看是否符合预期
            // 执行成功案例，参数为'test'
            expect(claser.method_1('test')).assertEqual('1'); // 执行通过
        })
    })
}
```

#### mockPrivateFunc<sup>1.0.25<sup>

mockPrivateFunc(originalObject: Object, method: String): Function

Mock某个类的实例上的私有方法，支持使用异步函数。

**参数：**

| 参数名    | 类型   | 必填 | 说明           |
|--------|------|----|--------------|
| originalObject | Object | 是  | 某个类的实例。      |
| method | String  | 是  | 类的实例上的私有方法名。 |

**返回值：**

| 类型             | 说明                            |
|----------------|-------------------------------|
| Function	 | 返回被Mock的函数。结合[when](#when)使用。 |


**示例：**
```javascript
import { ArgumentMatchers, describe, expect, it, MockKit, when } from '@ohos/hypium';

class ClassName {
    constructor() {}
    method(arg: number): number {
        return this.method_1(arg);
    }
    private method_1(arg: number) {
        return arg;
    }
}

export default function staticTest() {
    describe('privateTest', () => {
        it('private_001', 0, () => {
            let claser: ClassName = new ClassName();
            let really_result = claser.method(123);
            expect(really_result).assertEqual(123);
            // 1.创建MockKit对象
            let mocker: MockKit = new MockKit();
            // 2.Mock  类ClassName对象的私有方法，比如method_1
            let func_1: Function = mocker.mockPrivateFunc(claser, "method_1");
            // 3.期望被Mock后的函数返回结果456
            when(func_1)(ArgumentMatchers.any).afterReturn(456);
            let mock_result = claser.method(123);
            expect(mock_result).assertEqual(456);
        })
    })
}
```

#### mockProperty<sup>1.0.25<sup>

mockProperty(obj: Object, propertyName: String, value: any): void

Mock某个类的实例上的属性，将其值设置为预期值，支持私有属性。

**参数：**

| 参数名           | 类型   | 必填 | 说明            |
|---------------|------|----|---------------|
| Object        | obj | 是  | 某个类的实例。       |
| propertyName  |String  | 是  | 类的实例上的属性名称。   |
| value         |  any    |  是  | 期望被Mock后的属性值。 |

**示例：**
```javascript
import { describe, expect, it, MockKit } from '@ohos/hypium';

class ClassName {
    constructor() {
    }

    private priData = 2;

    method() {
        return this.priData;
    }
}

export default function staticTest() {
    describe('propertyTest', () => {
        it('property_001', 0, () => {
            let claser: ClassName = new ClassName();
            // 1.创建MockKit对象
            let mocker: MockKit = new MockKit();
            // 2.Mock  类ClassName对象的成员变量priData
            mocker.mockProperty(claser, "priData", 4);
            // 3.期望被Mock后的私有属性的值为4
            let mock_private_result = claser.method();
            expect(mock_private_result).assertEqual(4);
        })
    })
}
```

#### ignoreMock

ignoreMock(obj: Object, func: Function | String): void

还原实例中被Mock后的函数/属性，对被Mock后的函数/属性有效。

**参数：**

| 参数名       | 类型         | 必填 | 说明              |
|-----------|------------|----|-----------------|
| Object    | obj        | 是  | 某个类的实例。         |
| func | Function 或 String | 是  | 类的实例上的属性名字或者函数。 |

**示例**

```javascript
import { describe, expect, it, MockKit } from '@ohos/hypium';

class ClassName {
    constructor() {}

    private priData = 2;

    method() {
        return this.priData;
    }
}

export default function staticTest() {
    describe('propertyTest', () => {
        it('property_001', 0, () => {
            let claser: ClassName = new ClassName();
            // 1.创建MockKit对象
            let mocker: MockKit = new MockKit();
            // 2.Mock  类ClassName对象的私有属性priData
            mocker.mockProperty(claser, "priData", 4);
            // 3.期望被Mock后的私有属性的值为4
            expect(claser.method()).assertEqual(4);
            // 4.还原被Mock的属性
            mocker.ignoreMock(claser, "priData");
            // 5.私有属性priData的值被还原
            expect(claser.method()).assertEqual(2);
        })
    })
}
```

#### verify

`verify(methodName: String, argsArray: Array<any>): VerificationMode`

验证函数在对应参数下的执行行为是否符合预期，返回一个[VerificationMode](#verificationmode)类。

**参数：**

| 参数名       | 类型          | 必填 | 说明                        |
|-----------|-------------|----|---------------------------|
| methodName    | String      | 是  | 类的实例上的公共方法名。              |
| argsArray | `Array<any>` | 是  | 一个数组，表示期望该方法被调用时所传入的参数列表。 |

**返回值：**

| 类型             | 说明                  |
|----------------|---------------------|
| VerificationMode	 | 用于验证被Mock的函数的被调用次数。 |

示例：
```javascript
import { describe, it, MockKit } from '@ohos/hypium';

class ClassName {
  constructor() {
  }

  method_1(...arg: string[]) {
    return '888888';
  }

  method_2(...arg: string[]) {
    return '999999';
  }
}

export default function verifyTest() {
    describe('verifyTest', () => {
        it('testVerify', 0, () => {
            // 1.创建一个Mock能力的对象MockKit
            let mocker: MockKit = new MockKit();
            // 2.然后创建一个对象claser
            let claser: ClassName = new ClassName();
            // 3.进行Mock操作,比如需要对ClassName类的method_1和method_2两个函数进行Mock
            mocker.mockFunc(claser, claser.method_1);
            mocker.mockFunc(claser, claser.method_2);
            // 4.方法调用如下
            claser.method_1('abc', 'ppp');
            claser.method_2('111');
            // 5.现在对Mock后的两个函数进行验证，验证method_2,参数为'111'执行过一次
            mocker.verify('method_2', ['111']).once(); // 执行success
        })
    })
}
```

#### clear

clear(obj: Object): void

用例执行完毕后，进行被Mock的实例进行还原处理（还原之后对象恢复被Mock之前的功能）。


**参数：**

| 参数名       | 类型         | 必填 | 说明               |
|-----------|------------|----|------------------|
| Object    | obj        | 是  | 被Mock的实例对象。           |

**示例：**
```javascript
import { describe, expect, it, MockKit, when } from '@ohos/hypium';

class ClassName {
    
  constructor() {
  }
  
  method_1(...arg: number[]) {
    return '888888';
  }
}

export default function clearTest() {
    describe('clearTest', () => {
        it('testMockfunc', 0, () => {
            // 1.创建一个Mock能力的对象MockKit
            let mocker: MockKit = new MockKit();
            // 2.创建一个对象claser
            let claser: ClassName = new ClassName();
            // 3.进行Mock操作,比如需要对ClassName类的method_1函数进行Mock
            let func_1: Function = mocker.mockFunc(claser, claser.method_1);
            // 4.期望被Mock后的函数返回结果'4'
            when(func_1)(123).afterReturn('4');
            // 5.方法调用如下
            expect(claser.method_1(123)).assertEqual('4');
            // 6.清除obj上所有的Mock能力（原理是就是还原）
            mocker.clear(claser);
            // 7.然后再去调用 claser.method_1函数，测试结果
            expect(claser.method_1(123)).assertEqual('888888');
        })
    })
}

```

#### clearAll

clearAll(): void

用例执行完毕后，进行数据和内存清理，不会还原实例中被Mock后的函数。

**示例：**
```javascript
import { describe, expect, it, MockKit, when } from '@ohos/hypium';

class ClassName {
    
  constructor() {
  }
  
  method_1(...arg: number[]) {
    return '888888';
  }
}

export default function clearTest() {
    describe('clearAllTest', () => {
        it('testMockfunc', 0, () => {
            // 1.创建一个Mock能力的对象MockKit
            let mocker: MockKit = new MockKit();
            // 2.创建一个对象claser
            let claser: ClassName = new ClassName();
            // 3.进行Mock操作,比如需要对ClassName类的method_1函数进行Mock
            let func_1: Function = mocker.mockFunc(claser, claser.method_1);
            // 4.期望被Mock后的函数返回结果'4'
            when(func_1)(123).afterReturn('4');
            // 5.方法调用如下
            expect(claser.method_1(123)).assertEqual('4');
            // 6.进行数据和内存清理,不会还原实例中被Mock后的函数
            mocker.clearAll();
        })
    })
}

```


### when

when(fn: Function): Function

用于设置函数期望被Mock的值，使用when方法后需要使用afterXXX方法设置函数被Mock后的返回值或操作。


**参数：**

| 参数名       | 类型         | 必填 | 说明              |
|-----------|------------|----|-----------------|
| fn    | String        | 是  | 被MockKit处理后的函数。 |


**返回值：**

| 类型             | 说明                  |
|----------------|---------------------|
| Function	 | 返回一个Mock的中间函数，调用该函数返回一个[whenResult对象](#whenresult) |

**示例：**
```javascript
import { describe, it, MockKit, when } from '@ohos/hypium'

class ClassName {
  constructor() {
  }

  method_1(...arg: string[]) {
    return '888888';
  }
}

export default function verifyAtMostTest() {
    describe('verifyAtMostTest', () => {
        it('test_verify_atMost', 0, () => {
            // 1.创建MockKit对象
            let mocker: MockKit = new MockKit();
            // 2.创建类对象
            let claser: ClassName = new ClassName();
            // 3.Mock  类ClassName对象的某个方法，比如method_1
            let func_1: Function = mocker.mockFunc(claser, claser.method_1);
            // 4.期望被Mock后的函数返回结果'4'
            when(func_1)('abc').afterReturn('4');
            // 5.随机执行几次函数，参数如下
            claser.method_1('abc'); // 4
        })
    })
}
```

### whenResult

#### afterReturn

afterReturn(value: any): void

设定预期返回一个自定义的值，比如某个字符串或者一个promise。

**参数：**

| 参数名       | 类型         | 必填 | 说明      |
|-----------|------------|----|---------|
| value    | any        | 是  | 期望返回的值。 |


**示例：**
```javascript
import { describe, expect, it, MockKit, when } from '@ohos/hypium';

class ClassName {
    
  constructor() {
  }

  method_1(arg: string) {
    return '888888';
  }
}

export default function afterReturnTest() {
    describe('afterReturnTest', () => {
        it('afterReturnTest', 0, () => {
            // 1.创建一个Mock能力的对象MockKit
            let mocker: MockKit = new MockKit();
            // 2.定类ClassName，里面两个函数，然后创建一个对象claser
            let claser: ClassName = new ClassName();
            // 3.进行Mock操作,比如需要对ClassName类的method_1函数进行Mock
            let mockfunc: Function = mocker.mockFunc(claser, claser.method_1);
            // 4.期望claser.method_1函数被Mock后, 以'test'为入参时调用函数返回结果'1'
            when(mockfunc)('test').afterReturn('1');
            // 5.对Mock后的函数进行断言，看是否符合预期
            // 执行成功案例，参数为'test'
            expect(claser.method_1('test')).assertEqual('1'); // 执行通过
        })
    })
}
```

#### afterReturnNothing

afterReturnNothing(): void

设定预期没有返回值，即undefined。

**示例：**
```javascript
import { describe, expect, it, MockKit, when } from '@ohos/hypium';

class ClassName {
    
  constructor() {
  }

  method_1(arg: string) {
    return '888888';
  }
  
}

export default function afterReturnNothingTest() {
    describe('afterReturnNothingTest', () => {
        it('testMockfunc', 0, () => {
            // 1.创建一个Mock能力的对象MockKit
            let mocker: MockKit = new MockKit();
            // 2.定类ClassName，里面两个函数，然后创建一个对象claser
            let claser: ClassName = new ClassName();
            // 3.进行Mock操作,比如需要对ClassName类的method_1函数进行Mock
            let mockfunc: Function = mocker.mockFunc(claser, claser.method_1);
            // 4.期望claser.method_1函数被Mock后, 以'test'为入参时调用函数返回结果undefined
            when(mockfunc)('test').afterReturnNothing();
            // 5.对Mock后的函数进行断言，看是否符合预期，注意选择跟第4步中对应的断言方法
            // 执行成功案例，参数为'test'，这时候执行原对象claser.method_1的方法，会发生变化
            // 这时候执行的claser.method_1不会再返回'888888'，而是设定的afterReturnNothing()生效// 不返回任何值;
            expect(claser.method_1('test')).assertUndefined(); // 执行通过
        })
    })
}
```

#### afterAction

afterAction(action: Function): void

设定预期返回一个函数执行的操作。

**参数：**

| 参数名       | 类型         | 必填 | 说明     |
|-----------|------------|----|--------|
| action    | Function        | 是  | 一个回调函数，它会在目标方法被调用时执行。 |


示例：
```javascript
import { describe, expect, it, MockKit, when } from '@ohos/hypium';

class ClassName {
    
   constructor() {
   }

   method_1() {
      return 101010;
   }
}

function print(){
   return 123;
}

export default function mockAfterActionTest() {
    describe('mockAfterActionTest', () => {
        it('mockAfterActionTest', 0, () => {
            // 1.创建一个Mock能力的对象MockKit
            let mocker: MockKit = new MockKit();
            // 2.定类ClassName，里面两个函数，然后创建一个对象claser
            let claser: ClassName = new ClassName();
            // 3.进行Mock操作,比如需要对ClassName类的method_1函数进行Mock
            let mockfunc: Function = mocker.mockFunc(claser, claser.method_1);
            // 4.期望claser.method_1函数被Mock后, 以'test'为入参时调用函数返回结果'1'
            when(mockfunc)().afterAction(print);
            // 5.对Mock后的函数进行断言，看是否符合预期
            // 执行成功案例，参数为'test','test1'
            expect(claser.method_1()).assertEqual(123); // 执行通过
        })
    })
}
```

#### afterThrow

afterThrow(e_msg: string): void

设定预期抛出异常，并指定异常的message。

**参数：**

| 参数名       | 类型         | 必填 | 说明                                             |
|-----------|------------|----|------------------------------------------------|
| e_msg    | string        | 是  | 要抛出的错误的错误信息，最终会被包装成一个Error对象抛出。 |


示例：
```javascript
import { describe, expect, it, MockKit, when } from '@ohos/hypium';

class ClassName {
    
  constructor() {
  }

  method_1(arg: string) {
    return '888888';
  }
}

export default function afterThrowTest() {
    describe('afterThrowTest', () => {
        it('testMockfunc', 0, () => {
            console.info("it1 begin");
            // 1.创建一个Mock能力的对象MockKit
            let mocker: MockKit = new MockKit();
            // 2.创建一个对象claser
            let claser: ClassName = new ClassName();
            // 3.进行Mock操作,比如需要对ClassName类的method_1函数进行Mock
            let mockfunc: Function = mocker.mockFunc(claser, claser.method_1);
            // 4.期望claser.method_1函数被Mock后, 以'test'为参数调用函数时抛出error xxx异常
            when(mockfunc)('test').afterThrow('error xxx');
            // 5.执行Mock后的函数，捕捉异常并使用assertEqual对比msg否符合预期
            try {
                claser.method_1('test');
            } catch (e) {
                expect(e).assertEqual('error xxx'); // 执行通过
            }
        })
    })
}
```

### VerificationMode

#### times

times(count: Number): void

验证函数被调用过的次数符合预期。

**参数：**

| 参数名       | 类型         | 必填 | 说明     |
|-----------|------------|----|--------|
| count    | Number        | 是  | 调用的次数。 |


**示例：**
```javascript
import { describe, it, MockKit, when } from '@ohos/hypium'

class ClassName {
    
  constructor() {
  }

  method_1(...arg: string[]) {
    return '888888';
  }
}

export default function verifyTimesTest() {
    describe('verifyTimesTest', () => {
        it('test_verify_times', 0, () => {
            // 1.创建MockKit对象
            let mocker: MockKit = new MockKit();
            // 2.创建类对象
            let claser: ClassName = new ClassName();
            // 3.Mock 类ClassName对象的某个方法，比如method_1
            let func_1: Function = mocker.mockFunc(claser, claser.method_1);
            // 4.期望被Mock后的函数返回结果'4'
            when(func_1)('abc').afterReturn('4');
            // 5.随机执行几次函数，参数如下
            claser.method_1('abc');
            claser.method_1('abcd');
            claser.method_1('abc');
            // 6.验证函数method_1且参数为'abc'时，执行过的次数是否为2
            mocker.verify('method_1', ['abc']).times(2);
        })
    })
}

```


#### once

once(): void

验证函数被调用过一次。

**示例：**
```javascript
import { describe, it, MockKit } from '@ohos/hypium';

class ClassName {
    
  constructor() {
  }
  
  method_1(...arg: string[]) {
    return '888888';
  }
}

export default function verifyTest() {
    describe('verifyOnceTest', () => {
        it('test_verify_once', 0, () => {
            console.info("it1 begin");
            // 1.创建一个Mock能力的对象MockKit
            let mocker: MockKit = new MockKit();
            // 2.然后创建一个对象claser
            let claser: ClassName = new ClassName();
            // 3.进行Mock操作,比如需要对ClassName类的method_1函数进行Mock
            mocker.mockFunc(claser, claser.method_1);
            // 4.方法调用如下
            claser.method_1('abc');
            // 5.现在对Mock后的两个函数进行验证，验证method_2,参数为'111'执行过一次
            mocker.verify('method_1', ['abc']).once(); // 执行success
        })
    })
}
```

#### atLeast

atLeast(count: Number): void

验证函数被调用次数等于或超过指定值。

**参数：**

| 参数名       | 类型         | 必填 | 说明       |
|-----------|------------|----|----------|
| count    | Number        | 是  | 最少调用的次数。 |

**示例：**
```javascript
import { describe, it, MockKit, when } from '@ohos/hypium'

class ClassName {
    
    constructor() {
    }

    method_1(...arg: string[]) {
      return '888888';
    }
}

export default function verifyAtLeastTest() {
    describe('verifyAtLeastTest', () => {
        it('test_verify_atLeast', 0, () => {
            // 1.创建MockKit对象
            let mocker: MockKit = new MockKit();
            // 2.创建类对象
            let claser: ClassName = new ClassName();
            // 3.Mock  类ClassName对象的某个方法，比如method_1
            let func_1: Function = mocker.mockFunc(claser, claser.method_1);
            // 4.期望被Mock后的函数返回结果'4'
            when(func_1)('abc').afterReturn('4');
            // 5.随机执行几次函数，参数如下
            claser.method_1('abc');
            claser.method_1('abc');
            claser.method_1('abc');
            // 6.验证函数method_1且参数为'abc'时，是否至少执行过2次
            mocker.verify('method_1', ['abc']).atLeast(2);
        })
    })
}
```

#### atMost

atMost(count: Number): void

验证函数被调用次数等于或小于指定值。

**参数：**

| 参数名       | 类型         | 必填 | 说明       |
|-----------|------------|----|----------|
| count    | Number        | 是  | 最多调用的次数。 |

**示例：**
```javascript
import { describe, it, MockKit, when } from '@ohos/hypium'

class ClassName {
    
  constructor() {
  }

  method_1(...arg: string[]) {
    return '888888';
  }
}

export default function verifyAtMostTest() {
    describe('verifyAtMostTest', () => {
        it('test_verify_atMost', 0, () => {
            // 1.创建MockKit对象
            let mocker: MockKit = new MockKit();
            // 2.创建类对象
            let claser: ClassName = new ClassName();
            // 3.Mock  类ClassName对象的某个方法，比如method_1
            let func_1: Function = mocker.mockFunc(claser, claser.method_1);
            // 4.期望被Mock后的函数返回结果'4'
            when(func_1)('abc').afterReturn('4');
            // 5.随机执行几次函数，参数如下
            claser.method_1('abc');
            // 6.验证函数method_1且参数为空时，是否至多执行过2次
            mocker.verify('method_1', []).atMost(2);
        })
    })
}
```


#### never

never(): void

验证函数从未被被调用过。

**示例：**
```javascript
import { describe, it, MockKit } from '@ohos/hypium';

class ClassName {
    
  constructor() {
  }
  
  method_1(...arg: string[]) {
    return '888888';
  }
}

export default function verifyTest() {
    describe('verifyNeverTest', () => {
        it('test_verify_never', 0, () => {
            console.info("it1 begin");
            // 1.创建一个Mock能力的对象MockKit
            let mocker: MockKit = new MockKit();
            // 2.然后创建一个对象claser
            let claser: ClassName = new ClassName();
            // 3.进行Mock操作,比如需要对ClassName类的method_1函数进行Mock
            mocker.mockFunc(claser, claser.method_1);
            // 4.方法调用如下
            claser.method_1('abc');
            // 5.现在对Mock后的两个函数进行验证，验证method_2,参数为'111'从未被执行
            mocker.verify('method_1', ['111']).never(); // 执行success
        })
    })
}
```

### ArgumentMatchers

ArgumentMatchers用于在Mock函数时自定义函数参数，它的接口以枚举值或是函数的形式使用。

| 名称      | 值     | 说明                                                                      |
| -------- | ------------ | ------------------------------------------------------------------------------- |
| any    | -    | 设定用户传任何类型参数（undefined和null除外），执行的结果都是预期的值，使用ArgumentMatchers.any方式调用。                                 |
| anyString     | -    | 设定用户传任何字符串参数，执行的结果都是预期的值，使用ArgumentMatchers.anyString方式调用。                                    |
| anyBoolean | - | 设定用户传任何boolean类型参数，执行的结果都是预期的值，使用ArgumentMatchers.anyBoolean方式调用。 |
| anyFunction    | -     | 设定用户传任何function类型参数，执行的结果都是预期的值，使用ArgumentMatchers.anyFunction方式调用。                    |
| anyNumber     | -    | 设定用户传任何数字类型参数，执行的结果都是预期的值，使用ArgumentMatchers.anyNumber方式调用。                                   |
| anyObj | - | 设定用户传任何对象类型参数，执行的结果都是预期的值，使用ArgumentMatchers.anyObj方式调用。  |
| matchRegexs     | -    | 设定用户传任何符合正则表达式验证的参数，执行的结果都是预期的值，使用ArgumentMatchers.matchRegexs(Regex)方式调用。                  |


**示例：**

```javascript
import { ArgumentMatchers, describe, expect, it, MockKit, when } from '@ohos/hypium';

class ClassName {
    
  constructor() {
  }

  method_1(arg: string) {
    return '888888';
  }
}

export default function argumentMatchersAnyTest() {
    describe('argumentMatchersAnyTest', () => {
        it('testMockfunc', 0, () => {
            console.info("it1 begin");
            // 1.创建一个Mock能力的对象MockKit
            let mocker: MockKit = new MockKit();
            // 2.定类ClassName，里面两个函数，然后创建一个对象claser
            let claser: ClassName = new ClassName();
            // 3.进行Mock操作,比如需要对ClassName类的method_1函数进行Mock
            let mockfunc: Function = mocker.mockFunc(claser, claser.method_1);
            // 4.期望claser.method_1函数被Mock后, 以任何参数调用函数时返回结果'1'
            when(mockfunc)(ArgumentMatchers.any).afterReturn('1');
            // 5.对Mock后的函数进行断言，看是否符合预期，注意选择跟第4步中对应的断言方法
            // 执行成功的案例1，传参为字符串类型
            expect(claser.method_1('test')).assertEqual('1'); // 用例执行通过。
        })
    })
}
```

### TestType
用例类型，Hypium支持根据用例的类型筛选执行指定测试用例。

| 名称      | 值     | 说明      |
| -------- | ------------ |---------|
| FUNCTION    | 0B1     | 功能用例。   |
| PERFORMANCE     | 0B1 << 1    | 性能用例。   |
| POWER | 0B1 << 2 | 功耗用例。    |
| RELIABILITY    | 0B1 << 3     | 可靠性用例。  |
| SECURITY     | 0B1 << 4    | 安全性用例。  |
| GLOBAL | 0B1 << 5 | 全球化用例。  |
| COMPATIBILITY     | 0B1 << 6    | 兼容性用例。  |
| USER | 0B1 << 7 | 用户体验相关用例。 |
| STANDARD    | 0B1 << 8     | 标准用例。   |
| SAFETY     | 0B1 << 9    | 安全用例。   |
| RESILIENCE | 0B1 << 10 | 韧性测试。   |

### Size
用例规模，Hypium支持根据用例的规模筛选执行指定测试用例。

| 名称      | 值     | 说明    |
| -------- | ------------ |-------|
| SMALLTEST    | 0B1 << 16     | 小型用例。 |
| MEDIUMTEST     | 0B1 << 17    | 中型用例。 |
| LARGETEST | 0B1 << 18 | 大型用例。 |

### Level
用例规模，Hypium支持根据用例的规模筛选执行指定测试用例。

| 名称      | 值     | 说明    |
| -------- | ------------ |-------|
| LEVEL0    | 0B1 << 24     | 0级用例，一般是冒烟测试用例。 |
| LEVEL1     | 0B1 << 25    | 1级用例，一般是高优先级的核心功能用例。 |
| LEVEL2 | 0B1 << 26 | 2级用例，一般是中优先级的主要功能与异常场景用例。 |
| LEVEL3 | 0B1 << 27 | 3级用例，一般是低优先级边缘功能和复杂场景用例。 |
| LEVEL4 | 0B1 << 28 | 4级用例，一般是极低优先级的用户体验与探索性用例。 |

**示例：**

示例代码

```javascript
import { describe, it, Level, Size, TestType } from '@ohos/hypium';

export default function attributeTest() {
    describe('attributeTest', () => {
        it("testAttributeIt", TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL0, () => {
            console.info('Hello Test');
        })
    })
}
```

### Hypium



#### registerAssert

registerAssert(customAssertion: Function): void

注册自定义断言，结合[unregisterAssert](#unregisterassert)使用，用于实现用户自定义断言的注册和删除。

**参数：**

| 参数名       | 类型         | 必填 | 说明    |
|-----------|------------|----|-------|
| customAssertion    | Function        | 是  | 用户自定义的断言函数。 |

**示例：**

参见[unregisterAssert](#unregisterassert)中示例

#### unregisterAssert

unregisterAssert(customAssertion: string | Function): void

删除自定义断言，结合[registerAssert](#registerassert)使用，用于实现用户自定义断言的注册和删除。

**参数：**

| 参数名       | 类型         | 必填 | 说明    |
|-----------|------------|----|-------|
| customAssertion    | string 或 Function        | 是  | 用户自定义的断言函数或函数名称。 |

**示例：**
```javascript
import { Assert, beforeAll, describe, expect, Hypium, it } from '@ohos/hypium';

// custom.ets
interface customAssert extends Assert {
  // 自定义断言声明
  myAssertEqual(expectValue: boolean): void;
}

//自定义断言实现
let myAssertEqual = (actualValue: boolean, expectValue: boolean) => {
    
interface R {
  pass: boolean,
  message: string
}

let result: R = {
  pass: true,
  message: 'just is a msg'
}

let compare = () => {
    if (expectValue === actualValue) {
        result.pass = true;
        result.message = '';
    } else {
        result.pass = false;
        result.message = 'expectValue !== actualValue!';
    }
    return result;
}
result = compare();
return result;
}

export default function customAssertTest() {
    describe('customAssertTest', () => {
        beforeAll(() => {
            //注册自定义断言，只有先注册才可以使用
            Hypium.registerAssert(myAssertEqual);
        })
        it('assertContain1', 0, () => {
            let a = true;
            let b = true;
            (expect(a) as customAssert).myAssertEqual(b);
            Hypium.unregisterAssert(myAssertEqual);
        })
        it('assertContain2', 0, () => {
            Hypium.registerAssert(myAssertEqual);
            let a = true;
            let b = true;
            (expect(a) as customAssert).myAssertEqual(b);
            // 注销自定义断言，注销以后就无法使用
            Hypium.unregisterAssert(myAssertEqual);
            try {
                (expect(a) as customAssert).myAssertEqual(b);
            } catch (e) {
                expect(e.message).assertEqual("myAssertEqual is unregistered");
            }
        })
    })
}
```
#### setData

setData(data: Object): void

向测试框架中传递自定义参数，用于实现[数据驱动](https://gitcode.com/openharmony/testfwk_arkxtest/blob/master/README_zh.md#%E6%95%B0%E6%8D%AE%E9%A9%B1%E5%8A%A8)功能。

**参数：**

| 参数名       | 类型         | 必填 | 说明    |
|-----------|------------|----|-------|
| data    | Object        | 是  | 传入的自定义参数，只支持指定格式的对象类型。 |

**示例：**
```javascript
import AbilityDelegatorRegistry from '@ohos.application.abilityDelegatorRegistry'
import { Hypium } from '@ohos/hypium'
import testsuite from '../test/List.test'
import data from '../test/data.json';

Hypium.setData(data);  // 在hypiumTest前调用
Hypium.hypiumTest(abilityDelegator, abilityDelegatorArguments, testsuite);
```

## Hypium开放能力隐私声明

-  我们如何收集和使用您的个人信息

   您在使用集成了Hypium开放能力的测试应用时，Hypium不会处理您的个人信息。
-  SDK处理的个人信息

   不涉及。
-  SDK集成第三方服务声明

   不涉及。
-  SDK数据安全保护

   不涉及。
-  SDK版本更新声明

   为了向您提供最新的服务，我们会不时更新Hypium版本。我们强烈建议开发者集成使用最新版本的Hypium。
