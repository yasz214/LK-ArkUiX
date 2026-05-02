/*
 * The MIT License (MIT)
 * Copyright (C) 2023 Huawei Device Co., Ltd.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 */
'use strict';

import buildURL from '../../../lib/helpers/buildURL.js';
import settle from '../../../lib/core/settle';
import AxiosError from '../../../lib/core/AxiosError';
import request from '@ohos.request';
import fs from '@ohos.file.fs';
import { LogUtil } from '../../LogUtil'
import { setOptions, judgeMaxContentLength } from './index';

function download(httpConfig, resolve, reject) {
    const { httpRequest, fullPath, config } = httpConfig;
    let response = createInitialResponse(httpRequest, config);

    function settleResult(data, code) {
        response.data = data;
        response.status = code;
        settle(function _resolve(value) {
            resolve(value);
        }, function _reject(err) {
            reject(err);
        }, response);
    }

    try {
        const options = setOptions(config, opts => {
            if (config.filePath) {
                opts.filePath = config.filePath;
            }
        });

        const fileStream = fs.createStreamSync(options.filePath, 'a+');
        setupEventListeners(httpRequest, fileStream, config, response, reject);

        const url = buildURL(fullPath, config.params, config.paramsSerializer);
        httpRequest.requestInStream(url, options, handleRequestResult(httpRequest, response, config, settleResult, reject));

    } catch (err) {
        LogUtil.error('axios download error: %s', err.message);
        handleGlobalError(httpRequest, config, err, reject);
    }
}

function createInitialResponse(request, config) {
    return {
        data: null,
        status: 0,
        statusText: '',
        headers: config.headers || {},
        config: config,
        request: request
    };
}

function setupEventListeners(httpRequest, fileStream, config, response, reject) {
    httpRequest.on('headersReceive', onHeadersReceive(httpRequest, fileStream, response, config, reject));
    httpRequest.on('dataReceiveProgress', onDataReceiveProgress(config));
    httpRequest.on('dataReceive', onDataReceive(httpRequest, fileStream, config, reject));
    httpRequest.on('dataEnd', () => {
        removeEvent(httpRequest);
        fileStream.close();
    });
}

function onHeadersReceive(httpRequest, fileStream, response, config, reject) {
    return (header) => {
        response.headers = header;
        const totalSize = Number(header['content-length']);
        if (totalSize) {
            judgeMaxContentLength(totalSize, config, reject, httpRequest, validErrorCallback(httpRequest, fileStream));
        }
    };
}

function validErrorCallback(httpRequest, fileStream) {
    return (valid) => {
        // 校验失败，移除监听
        if (!valid) {
            removeEvent(httpRequest);
            fileStream.close();
        }
    };
}

function onDataReceiveProgress(config) {
    return ({ receiveSize, totalSize }) => {
        if (typeof config.onDownloadProgress === 'function') {
            config.onDownloadProgress({ loaded: receiveSize, total: totalSize });
        }
    };
}

function onDataReceive(httpRequest, fileStream, config, reject) {
    return (arraybuffer) => {
        try {
            handleStream(fileStream, arraybuffer);
        } catch (err) {
            LogUtil.error('axios onDataReceive error: %s', err.message);
            removeEvent(httpRequest);
            reject(new AxiosError(JSON.stringify(err), AxiosError.ERR_BAD_RESPONSE, config, request, request));
        }
    };
}

function handleStream(fileStream, arraybuffer) {
    if (!fileStream.writeSync(arraybuffer)) {
        setTimeout(() => {
            if (fileStream.writeSync(arraybuffer)) {
                clearTimeout(this);
            }
        }, 1000);
    }
}

function handleRequestResult(httpRequest, response, config, settleResult, reject) {
    return (err, data) => {
        response.status = data;
        if (!err && (data === 200 || data === 304)) {
            settleResult('download success!', data);
        } else {
            removeEvent(httpRequest);
            reject(new AxiosError(JSON.stringify(err), null, config, request, request));
        }
    };
}

function handleGlobalError(httpRequest, config, err, reject) {
    removeEvent(httpRequest);
    reject(new AxiosError(JSON.stringify(err), AxiosError.ERR_BAD_OPTION_VALUE, config, request, request));
}

// 移除监听
const removeEvent = (httpRequest) => {
    httpRequest.off('headersReceive');
    // 取消订阅HTTP流式响应数据接收事件
    httpRequest.off('dataReceive');
    // 取消订阅HTTP流式响应数据接收进度事件
    httpRequest.off('dataReceiveProgress');
    httpRequest.off('dataEnd');
    // 当该请求使用完毕时，调用destroy方法主动销毁
    httpRequest.destroy();
}

export default download
