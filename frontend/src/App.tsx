import { useState, useEffect } from "react";
import "./App.css";

interface Zone {
  zone_id: number;
  zone_name: string;
  region: string | null;
  office_address: string | null;
  office_phone: string | null;
}

function App() {
  const [zones, setZones] = useState<Zone[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch("/api/zones")
      .then((res) => {
        if (!res.ok) throw new Error("Failed to fetch zones");
        return res.json();
      })
      .then((data) => {
        setZones(data);
        setLoading(false);
      })
      .catch((err) => {
        setError(err.message);
        setLoading(false);
      });
  }, []);

  return (
    <div className="container">
      <h1>GOVT Utility Management System</h1>
      <h2>Zones</h2>

      {loading && <p>Loading...</p>}
      {error && <p className="error">Error: {error}</p>}

      {!loading && !error && (
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>Zone Name</th>
              <th>Region</th>
              <th>Office Address</th>
              <th>Phone</th>
            </tr>
          </thead>
          <tbody>
            {zones.map((zone) => (
              <tr key={zone.zone_id}>
                <td>{zone.zone_id}</td>
                <td>{zone.zone_name}</td>
                <td>{zone.region || "-"}</td>
                <td>{zone.office_address || "-"}</td>
                <td>{zone.office_phone || "-"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}

export default App;
