# =============================================================================
# start.sh - Start the admin stack
# =============================================================================

echo "Starting admin stack..."
docker compose up -d
echo ""
echo "Waiting for containers to start (10 seconds)..."
sleep 10

echo ""
echo "Container status:"
docker compose ps

echo ""
echo "Admin stack started!"
echo ""
echo "Useful commands:"
echo "  docker compose logs -f              # View all logs"
echo "  docker compose logs -f traefik      # Traefik logs"
echo "  docker compose ps                   # Container status"
echo "  docker compose down                 # Stop the stack"
echo "  docker compose restart              # Restart the stack"
echo ""
echo "IMPORTANT: You must log into Portainer within 5 minutes after first startup."
echo "Access Portainer at:"
echo "  http://10.13.13.1:9000  (direct access)"
