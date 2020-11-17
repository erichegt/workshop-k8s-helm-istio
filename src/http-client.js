const fetch = require('node-fetch');

const TRACE_HEADERS = {
	'b3': true,
	'x-b3-flags': true,
	'x-b3-parentspanid': true,
	'x-b3-sampled': true,
	'x-b3-spanid': true,
	'x-b3-traceid': true,
	'x-ot-span-context': true,
	'x-request-id': true,
};

const filterTracingHeaders = headers => Object.assign(...Object.entries(headers).map(([header, value]) => {
	const exists = TRACE_HEADERS[header.toLowerCase()];
	return exists ? { [header]: value } : {};
}));

const makeRequest = async (url, options) => {
    const newOptions = { headers: {} }
    Object.assign(newOptions.headers, filterTracingHeaders(options.headers));
    const res = await fetch(url, newOptions);
	if (!res.ok) {
		throw new Error(res.status);
    }
	return res.json();
};

module.exports = {
	get: (url, headers = {}) => makeRequest(url, { headers }),
	post: (url, body, headers = {}) => makeRequest(url, { body, headers, method: 'post' }),
};