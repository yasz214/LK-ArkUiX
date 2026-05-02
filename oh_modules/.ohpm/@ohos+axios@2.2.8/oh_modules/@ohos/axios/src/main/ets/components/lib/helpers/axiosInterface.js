'use strict';

import axios from '../axios';

/**
 * Set the fields in the Header
 * @param key key
 * @param value value
 * @param axiosInstance other axios
 */
export function setHeaderKey(key, value, axiosInstance = null) {
    const target = axiosInstance ? axiosInstance.defaults.headers : axios.defaults.headers;
    target[key] = value;
}

/**
 * Delete the fields in the header
 * @param key key
 * @param axiosInstance other axios
 */
export function deleteHeaderKey(key, axiosInstance = null) {
    const target = axiosInstance ? axiosInstance.defaults.headers : axios.defaults.headers;
    delete target[key];
}
