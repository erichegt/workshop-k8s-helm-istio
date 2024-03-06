const httpClient = require('./http-client');
// Require the framework and instantiate it
const fastify = require('fastify')({ logger: true })
// import fastify from 'fastify';

let chaos = !(process.env.AVOID_CHAOS==="true");
let delay = false;
let nextService = process.env.NEXT_SVC_URL;
let delayValue = process.env.DELAY_VALUE || 6000;
let currentPodName = process.env.POD_NAME;
let version = 'v0.7';

async function wait(ms) {
  return new Promise(resolve => {
    setTimeout(resolve, ms);
  });
}

let errorResponse = (reply) => {
  return reply
    .code(500)
    .header('Content-Type', 'application/json; charset=utf-8')
    .send({ error_message: 'deu ruim' })
}

fastify.get('/', async (request, reply) => {
  if (chaos) {
    return errorResponse(reply);
  }
  return { hello: 'world', version }
})

fastify.get('/chain', async (request, reply) => {
  if (chaos) {
    return errorResponse(reply);
  }
  if (delay) {
    await wait(delayValue);
  }
  const pod = { pod: `${currentPodName}`, version };
  if (nextService) {
    try {
      const chain = await httpClient.get(`http://${nextService}/chain`, request.headers);
      return { from : pod, chain }
    } catch (e) {
      return { from: pod, error: { service: nextService, status_code: e.status } }
    }
  }
  return { chain_end : pod }
})

fastify.post('/changeCaos', async (request, reply) => {
  chaos = !chaos;
  return { msg: `chaos changed to: ${chaos}` }
})

fastify.post('/changeDelay', async (request, reply) => {
  delay = !delay;
  return { msg: `delay changed to: ${delay}` }
})

// Run the server!
const start = async () => {
  try {
    await fastify.listen(3000, '0.0.0.0')
    fastify.log.info(`server listening on ${fastify.server.address().port}`)
  } catch (err) {
    fastify.log.error(err)
    process.exit(1)
  }
}
start()
