const map = L.map('map').setView([40.754, -73.98], 12);
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);

let allMarkers = [];
let markerGroup = L.markerClusterGroup();
let propertyData = [];
let activityFilters = [];

let selectedActivities = new Set();
let constructionFilters = new Set();

// Load and filter data
Promise.all([
  fetch('data/properties.json').then(res => res.json()),
  fetch('data/activities.json').then(res => res.json())
])
  .then(([properties, activities]) => {
      propertyData = properties;
      activityFilters = activities;

      updateMarkers(); // displays all markers with no filters set yet
      createFilterButtons();
      createConstructionButtons();
    });

function createFilterButtons() {
  const filterContainer = document.getElementById('filter-buttons');
  activityFilters.forEach(activity => {
    const btn = document.createElement('button');
    btn.textContent = activity;
    btn.dataset.activity = activity;

    btn.addEventListener('click', () => {
      btn.classList.toggle('active');

      if (selectedActivities.has(activity)) {
        selectedActivities.delete(activity);
      } else {
        selectedActivities.add(activity);
      }

      updateMarkers();
    });

    filterContainer.appendChild(btn);
  });
}

function createConstructionButtons() {
  const container = document.getElementById('construction-buttons');
  const options = [
    { label: "UNDER CONSTRUCTION", value: "YES" },
    { label: "NOT UNDER CONSTRUCTION", value: "NO" }
  ];

  options.forEach(option => {
    const btn = document.createElement('button');
    btn.textContent = option.label;
    btn.dataset.value = option.value;

    btn.addEventListener('click', () => {
      btn.classList.toggle('active');

      if (constructionFilters.has(option.value)) {
        constructionFilters.delete(option.value);
      } else {
        constructionFilters.add(option.value);
      }

      updateMarkers();
    });

    container.appendChild(btn);
  });
}

function updateMarkers() {
  markerGroup.clearLayers();

  const filtered = propertyData.filter(p => {
    const lat = parseFloat(p.latitude);
    const lon = parseFloat(p.longitude);
    if (!lat || !lon) return false;

    const activity = p.primary_business_activity || 'UNKNOWN';
    const construction = (p.construction_reported === "YES") ? "YES" : "NO";

    // filter by activity
    if (selectedActivities.size > 0 && !selectedActivities.has(activity)) {
      return false;
    }

    // filter by construction
    if (constructionFilters.size > 0 && !constructionFilters.has(construction)) {
      return false;
    }

    // if both filters pass, return true
    return true;
  });

  filtered.forEach(p => {
    const marker = L.marker([parseFloat(p.latitude), parseFloat(p.longitude)]);
    const popup = `
      <strong>${p.property_street_address_or || 'Unknown address'}</strong><br/>
      Activity: ${p.primary_business_activity || 'N/A'}<br/>
      Borough: ${p.borough || 'N/A'}<br/>
      Vacant 6/30: ${p.vacant_6_30_or_date_sold || 'N/A'}
    `;
    marker.bindPopup(popup);
    markerGroup.addLayer(marker);
  });

  map.addLayer(markerGroup);
}
