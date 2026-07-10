// The wall's own address — /feed — so the surface is walkable and
// verifiable long before the Phase 4 homepage flip touches Canvas.
export default function () {
  this.route("vc-feed", { path: "/feed" });
}
