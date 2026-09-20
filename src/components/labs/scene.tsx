"use client";
import { useEffect, useRef } from "react";
import * as T from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { parts, type LabKind, type Wire } from "@/lib/labs";
type Point = [number, number, number];
const terminals: Record<string, Point> = { "Source L": [-3, 1, 0], "Source N": [-3, 0, 0], "Source PE": [-3, -1, 0], "Switch in": [-1, 1, 0], "Switch out": [0, 1, 0], "Load L": [2.3, 1, 0], "Load N": [2.3, 0, 0], "Load case": [2.3, -1, 0] };
export default function LabScene({ kind, wires, active, exploded, selected, onSelect, placements, onPlace }: { kind: LabKind; wires: Wire[]; active: boolean; exploded: boolean; selected: number; onSelect: (i: number) => void; placements: number[]; onPlace: (i: number) => void }) {
  const host = useRef<HTMLDivElement>(null);
  const handlers = useRef({ onSelect, onPlace });
  const view = useRef<Point>([0, 3, 9]);
  useEffect(() => { handlers.current = { onSelect, onPlace }; }, [onSelect, onPlace]);
  useEffect(() => {
    const container = host.current; if (!container) return;
    let renderer: T.WebGLRenderer;
    try { renderer = new T.WebGLRenderer({ antialias: true }); } catch { container.textContent = "3D unavailable. Continue with the labeled exercise controls below."; return; }
    renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5)); container.appendChild(renderer.domElement);
    renderer.domElement.setAttribute("aria-label", "Interactive model; equivalent labeled controls follow below.");
    const scene = new T.Scene(); scene.background = new T.Color("#101e2e");
    const camera = new T.PerspectiveCamera(45, 1, 0.1, 100); camera.position.set(...view.current);
    const controls = new OrbitControls(camera, renderer.domElement); controls.minDistance = 5; controls.maxDistance = 15; controls.enablePan = false;
    scene.add(new T.AmbientLight(0xffffff, 2)); const light = new T.DirectionalLight(0xffffff, 3); light.position.set(4, 6, 8); scene.add(light);
    const clickable: T.Mesh[] = []; const textures: T.Texture[] = [];
    function box(p: Point, size: Point, color: string, index?: number) { const mesh = new T.Mesh(new T.BoxGeometry(...size), new T.MeshStandardMaterial({ color, roughness: 0.5, metalness: 0.2 })); mesh.position.set(...p); mesh.userData.index = index; scene.add(mesh); clickable.push(mesh); }
    function label(text: string, p: Point, width = 1.8) { const c = document.createElement("canvas"); c.width = 512; c.height = 80; const ctx = c.getContext("2d"); if (!ctx) return; ctx.fillStyle = "#101e2e"; ctx.fillRect(0, 0, 512, 80); ctx.fillStyle = "#e4edf5"; ctx.font = "32px sans-serif"; ctx.textAlign = "center"; ctx.fillText(text, 256, 52); const texture = new T.CanvasTexture(c); textures.push(texture); const sprite = new T.Sprite(new T.SpriteMaterial({ map: texture })); sprite.position.set(...p); sprite.scale.set(width, 0.28, 1); scene.add(sprite); }
    if (kind === "explorer" || kind === "safety") {
      box([0, 0, -0.45], [3.7, 4.4, 0.25], selected === 0 ? "#4ffff0" : parts[0].color, 0);
      const coords: Point[] = [[0, 1.4, 0], [0, 0, -0.1], [0.65, 0, 0.15], [-1.25, 0, 0], [1.25, -1, 0]];
      const sizes: Point[] = [[1.1, 0.65, 0.5], [0.65, 2, 0.12], [0.65, 1.7, 0.45], [0.2, 1.8, 0.2], [0.2, 1, 0.2]];
      parts.slice(1).forEach((p, i) => { const pos: Point = [coords[i][0] + (exploded ? (i % 2 ? -1.2 : 1.2) : 0), coords[i][1], coords[i][2] + (exploded ? 1 + i * 0.3 : 0)]; box(pos, sizes[i], selected === i + 1 ? "#4ffff0" : p.color, i + 1); if (selected === i + 1) label(p.name, [pos[0], pos[1] + 0.7, pos[2]]); });
    } else if (kind === "room") {
      box([0, -1, 0], [8, 0.1, 4], "#30465b"); box([0, 0.3, -1.8], [8, 2.6, 0.12], "#7990a4");
      for (let i = 0; i < 10; i++) { box([-3.6 + i * 0.8, -0.5, -1.65], [0.3, 0.4, 0.15], placements.includes(i) ? "#83e5b6" : "#3b5367", i); label(`${i * 2 + 1} ft`, [-3.6 + i * 0.8, -1.1, -1.3], 0.7); }
    } else {
      box([-3.1, 0, -0.35], [1, 3, 0.4], "#34495f"); box([-0.5, 1, -0.25], [1.5, 0.8, 0.25], "#6c849a");
      const lamp = new T.Mesh(new T.SphereGeometry(0.85, 24, 24), new T.MeshStandardMaterial({ color: active ? "#f8d778" : "#637c90", emissive: active ? "#f8c13c" : "#000000", emissiveIntensity: 0.7 })); lamp.position.set(2.3, 0, -0.3); scene.add(lamp);
      Object.entries(terminals).forEach(([name, p]) => { box(p, [0.14, 0.14, 0.14], "#e8eefa"); label(name, [p[0], p[1] + 0.28, p[2]]); });
      wires.forEach((w, i) => { const a = terminals[w.from], b = terminals[w.to]; const curve = new T.CatmullRomCurve3([new T.Vector3(...a), new T.Vector3(a[0] + 0.3, a[1] + 0.4 + i * 0.1, 0.6), new T.Vector3(b[0] - 0.3, a[1] + 0.4 + i * 0.1, 0.6), new T.Vector3(...b)]); scene.add(new T.Mesh(new T.TubeGeometry(curve, 32, 0.025, 6, false), new T.MeshStandardMaterial({ color: w.from.includes("PE") || w.to.includes("case") ? "#6fe5aa" : w.from.endsWith("N") || w.to.endsWith("N") ? "#eaf0f6" : "#ffc36f" }))); });
    }
    const render = () => { view.current = camera.position.toArray() as Point; renderer.render(scene, camera); };
    const resize = () => { const w = container.clientWidth, h = container.clientHeight; if (!w || !h) return; renderer.setSize(w, h); camera.aspect = w / h; camera.updateProjectionMatrix(); render(); };
    const observer = new ResizeObserver(resize); observer.observe(container); controls.addEventListener("change", render); resize();
    let start = [0, 0];
    const down = (e: PointerEvent) => { start = [e.clientX, e.clientY]; };
    const click = (e: PointerEvent) => { if (Math.hypot(e.clientX - start[0], e.clientY - start[1]) > 5) return; const r = renderer.domElement.getBoundingClientRect(); const ray = new T.Raycaster(); ray.setFromCamera(new T.Vector2((e.clientX - r.left) / r.width * 2 - 1, -(e.clientY - r.top) / r.height * 2 + 1), camera); const hit = ray.intersectObjects(clickable)[0]; if (hit && typeof hit.object.userData.index === "number") { if (kind === "room") handlers.current.onPlace(hit.object.userData.index); else handlers.current.onSelect(hit.object.userData.index); } };
    renderer.domElement.addEventListener("pointerdown", down); renderer.domElement.addEventListener("pointerup", click);
    return () => { observer.disconnect(); controls.dispose(); renderer.domElement.removeEventListener("pointerdown", down); renderer.domElement.removeEventListener("pointerup", click); scene.traverse(o => { if (o instanceof T.Mesh || o instanceof T.Sprite) { if (o instanceof T.Mesh) o.geometry.dispose(); (Array.isArray(o.material) ? o.material : [o.material]).forEach(m => m.dispose()); } }); textures.forEach(t => t.dispose()); renderer.dispose(); renderer.domElement.remove(); };
  }, [kind, wires, active, exploded, selected, placements]);
  return <div ref={host} className="h-full w-full text-white"/>;
}
