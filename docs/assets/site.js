document.addEventListener("DOMContentLoaded", () => {
  const toggle = document.querySelector(".nav-toggle");
  const sidebar = document.querySelector("#sidebar");
  const backdrop = document.querySelector("#sidebar-backdrop");

  const close = () => {
    document.body.classList.remove("sidebar-open");
    if (backdrop) backdrop.hidden = true;
  };

  const open = () => {
    document.body.classList.add("sidebar-open");
    if (backdrop) backdrop.hidden = false;
  };

  if (toggle && sidebar) {
    toggle.addEventListener("click", () => {
      if (document.body.classList.contains("sidebar-open")) close();
      else open();
    });
  }

  if (backdrop) {
    backdrop.addEventListener("click", close);
  }

  const targets = document.querySelectorAll(
    ".panel, .callout, .table-wrap, .pipeline-figure, pre, .gallery figure"
  );
  targets.forEach((el) => el.classList.add("reveal"));

  if ("IntersectionObserver" in window) {
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("in");
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.12 }
    );
    targets.forEach((el) => io.observe(el));
  } else {
    targets.forEach((el) => el.classList.add("in"));
  }
});
