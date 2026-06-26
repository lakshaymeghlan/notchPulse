/** Ultra-soft pastel blobs the glass surfaces refract. Subtle on white. */
export default function Backdrop() {
  return (
    <div aria-hidden className="pointer-events-none fixed inset-0 -z-10 overflow-hidden">
      <div className="blob" style={{ width: 520, height: 520, left: "-8%", top: "-6%", background: "#BFD3FF", animation: "drift 22s ease-in-out infinite" }} />
      <div className="blob" style={{ width: 460, height: 460, right: "-6%", top: "12%", background: "#FFD8C2", animation: "drift 26s ease-in-out infinite reverse" }} />
      <div className="blob" style={{ width: 540, height: 540, left: "30%", bottom: "-12%", background: "#C8F2E4", animation: "drift 30s ease-in-out infinite" }} />
    </div>
  );
}
