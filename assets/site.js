document.addEventListener("DOMContentLoaded", () => {
  const toggle = document.querySelector(".nav-toggle");
  const mobile = document.querySelector("#mobile-nav");
  if (toggle && mobile) {
    toggle.addEventListener("click", () => {
      mobile.classList.toggle("open");
    });
  }

  const targets = document.querySelectorAll(
    ".panel, .callout, .table-wrap, .pipeline-figure, .hero-visual, pre, .gallery figure"
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
