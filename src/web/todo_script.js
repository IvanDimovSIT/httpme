const listEl = document.getElementById("items");
const formEl = document.getElementById("add-form");
const inputEl = document.getElementById("item-input");

async function fetchItems() {
  const res = await fetch("/api/items");
  const items = await res.json();
  renderItems(items);
}

function renderItems(items) {
  listEl.innerHTML = "";

  for (const item of items) {
    const li = document.createElement("li");

    const name = document.createElement("span");
    name.textContent = item.name;
    if (item.is_complete) {
      name.classList.add("done");
    }

    const btn = document.createElement("button");
    btn.textContent = item.is_complete ? "Undo" : "✓";

    btn.onclick = async () => {
      await fetch(`/api/items/toggle/${item.id}`, {
        method: "PUT",
      });
      fetchItems();
    };

    li.appendChild(name);
    li.appendChild(btn);
    listEl.appendChild(li);
  }
}

formEl.addEventListener("submit", async (e) => {
  e.preventDefault();

  const name = inputEl.value.trim();
  if (!name) return;

  await fetch("/api/item", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ name }),
  });

  inputEl.value = "";
  fetchItems();
});

// initial load
fetchItems();
