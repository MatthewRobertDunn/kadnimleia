import ./server/kad_server

echo("Hello World")

let server = kad_server.KadServer().toConcept()
echo(server.ping())