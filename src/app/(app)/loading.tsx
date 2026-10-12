export default function WorkspaceLoading() {
  return <div className="mx-auto max-w-[1120px] animate-pulse px-4 py-10 md:px-8"><div className="h-3 w-28 rounded bg-[var(--line)]"/><div className="mt-4 h-10 w-2/3 rounded-xl bg-[var(--line)]"/><div className="mt-8 grid gap-5 md:grid-cols-2"><div className="h-64 rounded-[26px] bg-[var(--surface)]"/><div className="h-64 rounded-[26px] bg-[var(--surface)]"/></div><div className="mt-5 grid grid-cols-2 gap-4 md:grid-cols-4">{Array.from({ length: 4 }, (_, index) => <div key={index} className="h-28 rounded-[20px] bg-[var(--surface)]"/>)}</div></div>;
}

