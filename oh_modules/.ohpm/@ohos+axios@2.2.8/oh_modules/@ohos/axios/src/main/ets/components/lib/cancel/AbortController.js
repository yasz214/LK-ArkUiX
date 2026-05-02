/*
 * The MIT License (MIT)
 * Copyright (C) 2025 Huawei Device Co., Ltd.
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
import CanceledError from './CanceledError';

class Emitter {
    listeners = {};
    addEventListener(eventName, callback) {
        if (!(eventName in this.listeners)) {
            this.listeners[eventName] = [];
        }
        this.listeners[eventName].push({ callback });
    }
    removeEventListener(eventName, callback) {
        if (!(eventName in this.listeners)) {
            return;
        }
        const stack = this.listeners[eventName];
        for (let i = 0, l = stack.length; i < l; i++) {
            if (stack[i].callback === callback) {
                stack.splice(i, 1);
                if (stack.length === 0) {
                    delete this.listeners[eventName];
                }
                return;
            }
        }
    }
    dispatchEvent(event, reason) {
        const eventName = event.type;
        if (!eventName || !(eventName in this.listeners)) {
            return;
        }
        const stack = this.listeners[eventName];
        const stackToCall = stack.slice();
        for (let i = 0, l = stackToCall.length; i < l; i++) {
            const listener = stackToCall[i];
            try {
                listener.callback.call(this, reason ? reason : event);
            } catch (e) {
                Promise.resolve().then(() => {
                    throw e;
                });
            }
        }
    }
}

export class AbortSignal extends Emitter {
    constructor() {
        super();
        Object.defineProperty(this, 'aborted', { value: false, writable: true, configurable: true });
        Object.defineProperty(this, 'onabort', { value: null, writable: true, configurable: true });
        Object.defineProperty(this, 'reason', { value: undefined, writable: true, configurable: true });
    }
    toString() {
        return '[object AbortSignal]';
    }
    dispatchEvent(event) {
        if (event?.type === 'abort') {
            this.aborted = true;
            if (typeof this.onabort === 'function') {
                this.onabort.call(this, this.reason);
            }
        }
        super.dispatchEvent(event, this.reason);
    }
}

export class AbortController {
    constructor() {
        this.signal = new AbortSignal();
    }
    abort(reason) {
        if (this.signal.aborted) {
            return;
        }

        this.signal.aborted = true;

        this.signal.reason = reason || new Error('This operation was aborted');

        this.signal.dispatchEvent({
            type: 'abort'
        });
    }
    toString() {
        return '[object AbortController]';
    }
}