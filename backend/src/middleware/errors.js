export function notFound(_request, response) {
  response.status(404).json({ error: { code: 'NOT_FOUND', message: 'Route not found' } });
}

// Express identifies an error middleware by its four-argument signature.
export function errorHandler(error, _request, response, _next) {
  const status = Number.isInteger(error.status) && error.status >= 400 && error.status < 500
    ? error.status : 500;
  response.status(status).json({
    error: { code: status === 500 ? 'INTERNAL_ERROR' : 'INVALID_REQUEST', message: status === 500 ? 'Internal server error' : 'Invalid request' },
  });
}

