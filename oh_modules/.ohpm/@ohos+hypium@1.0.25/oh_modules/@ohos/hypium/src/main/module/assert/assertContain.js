/*
 * Copyright (c) 2021-2022 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

function assertContain(actualValue, expect) {
    let result = false;
    if (Object.prototype.toString.call(actualValue).indexOf('Array')) {
        for (let value of actualValue) {
            if (value === expect[0]) {
                result = true;
            }
        }
    }
    let type = Object.prototype.toString.call(actualValue);
    if (type === '[object String]') {
        result = actualValue.indexOf(expect[0]) >= 0;
    }
    let actualValueStr = (actualValue === null || actualValue === undefined) ? actualValue : actualValue.toString();
    let expectStr = (expect[0] === null || expect[0] === undefined) ? expect[0] : expect[0].toString();
    return {
        pass: result,
        message: 'expect false, ' + actualValueStr + ' do not have  ' + expectStr
    };
}

export default assertContain;
