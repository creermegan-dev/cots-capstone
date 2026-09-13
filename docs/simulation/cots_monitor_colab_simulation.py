# COTS Monitor — Classification simulation for Google Colab
# Copy each "# %%" section into a separate Colab cell, or run as one script in Colab.

# %% Cell 1 — Install / import
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.metrics import confusion_matrix, classification_report, accuracy_score

sns.set(style="whitegrid")
plt.rcParams["figure.figsize"] = (9, 5)

# COTS Monitor policy (matches lib/models/cots_confidence_policy.dart)
AUTO_APPROVE_MIN = 74
ADMIN_REVIEW_MIN = 20

# Severity buckets (matches UserDashboardAnalytics.fromRecords)
def severity_label(count: int) -> str:
    if count >= 15:
        return "High"
    if count >= 5:
        return "Medium"
    return "Low"

def confidence_band(pct: float) -> str:
    if pct >= AUTO_APPROVE_MIN:
        return f"High (≥{AUTO_APPROVE_MIN}%)"
    if pct >= ADMIN_REVIEW_MIN:
        return f"Medium ({ADMIN_REVIEW_MIN}–{AUTO_APPROVE_MIN - 1}%)"
    return f"Low (<{ADMIN_REVIEW_MIN}%)"

# %% Cell 2 — Upload CSV
from google.colab import files
uploaded = files.upload()
filename = list(uploaded.keys())[0]
df = pd.read_csv(filename)
print("Columns:", df.columns.tolist())
print(df.head())

# %% Cell 3 — Derive labels from COTS Monitor fields if missing
def normalize_label(x):
    s = str(x).strip().lower()
    if s in ["1", "present", "yes", "true", "cots present"]:
        return 1
    if s in ["0", "absent", "no", "false", "cots absent"]:
        return 0
    return np.nan

# Required: ai_detected_count OR predicted_label; confidence; date; zone
if "ai_detected_count" not in df.columns and "detection_count" in df.columns:
    df["ai_detected_count"] = df["detection_count"]

if "predicted_label" not in df.columns:
    df["predicted_label"] = (df["ai_detected_count"].fillna(0).astype(int) > 0).astype(int)

if "actual_label" not in df.columns:
    if "admin_confirmed" in df.columns and "admin_rejected" in df.columns:
        def actual_row(row):
            if bool(row.get("admin_confirmed")):
                return 1
            if bool(row.get("admin_rejected")):
                return 0
            return 1 if int(row.get("ai_detected_count", 0) or 0) > 0 else 0
        df["actual_label"] = df.apply(actual_row, axis=1)
    else:
        df["actual_label"] = df["predicted_label"]

df["predicted_label"] = df["predicted_label"].apply(normalize_label)
df["actual_label"] = df["actual_label"].apply(normalize_label)
df["confidence"] = pd.to_numeric(df["confidence"], errors="coerce")
if "confidence_percent" not in df.columns:
    df["confidence_percent"] = (df["confidence"].clip(0, 1) * 100).round()
df["date"] = pd.to_datetime(df["date"], errors="coerce")
df["ai_detected_count"] = pd.to_numeric(df.get("ai_detected_count", 0), errors="coerce").fillna(0).astype(int)
df["severity"] = df["ai_detected_count"].apply(severity_label)
df["confidence_band"] = df["confidence_percent"].apply(confidence_band)

df = df.dropna(subset=["predicted_label", "actual_label", "confidence", "date", "zone"]).copy()
df["predicted_label"] = df["predicted_label"].astype(int)
df["actual_label"] = df["actual_label"].astype(int)

print(f"\nCOTS Monitor simulation rows: {len(df)}")
print(df[["zone", "ai_detected_count", "confidence_percent", "predicted_label", "actual_label", "severity"]].head())

# %% Cell 4 — Classification metrics
acc = accuracy_score(df["actual_label"], df["predicted_label"])
print(f"Accuracy: {acc:.3f}")
print(classification_report(
    df["actual_label"], df["predicted_label"],
    target_names=["Absent", "Present"], zero_division=0,
))

# %% Cell 5 — Graph 1: Predicted class distribution
plt.figure()
sns.countplot(
    x=df["predicted_label"].map({0: "Absent", 1: "Present"}),
    palette=["#43A047", "#E53935"],
)
plt.title("Graph 1 — Predicted classification (YOLO: ai_detected_count > 0)")
plt.xlabel("Class")
plt.ylabel("Scan records")
plt.tight_layout()
plt.savefig("graph1_class_distribution.png", dpi=300)
plt.show()

# %% Cell 6 — Graph 2: Confidence distribution
plt.figure()
sns.histplot(df["confidence_percent"], bins=20, kde=True, color="#00BFA5")
plt.axvline(AUTO_APPROVE_MIN, color="green", linestyle="--", label=f"Auto-approve {AUTO_APPROVE_MIN}%")
plt.axvline(ADMIN_REVIEW_MIN, color="orange", linestyle="--", label=f"Admin review {ADMIN_REVIEW_MIN}%")
plt.legend()
plt.title("Graph 2 — Confidence % (CotsConfidencePolicy)")
plt.xlabel("Confidence %")
plt.tight_layout()
plt.savefig("graph2_confidence_distribution.png", dpi=300)
plt.show()

# %% Cell 7 — Graph 3: Confusion matrix
cm = confusion_matrix(df["actual_label"], df["predicted_label"])
plt.figure()
sns.heatmap(
    cm, annot=True, fmt="d", cmap="Blues",
    xticklabels=["Pred Absent", "Pred Present"],
    yticklabels=["Actual Absent", "Actual Present"],
)
plt.title("Graph 3 — AI vs ground truth (admin / actual_label)")
plt.tight_layout()
plt.savefig("graph3_confusion_matrix.png", dpi=300)
plt.show()

# %% Cell 8 — Graph 4: COTS trend (like user dashboard daily trend)
daily = (
    df.groupby(df["date"].dt.date)["ai_detected_count"]
    .sum()
    .reset_index()
)
plt.figure()
sns.lineplot(data=daily, x="date", y="ai_detected_count", marker="o", color="#2563EB")
plt.title("Graph 4 — Total ai_detected_count over time")
plt.xlabel("Date")
plt.ylabel("COTS count (sum per day)")
plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig("graph4_detection_trend.png", dpi=300)
plt.show()

# %% Cell 9 — Graph 5: Zone risk (Zone A–D from your GIS map)
zone_stats = df.groupby("zone").agg(
    scans=("predicted_label", "count"),
    present=("predicted_label", "sum"),
    total_cots=("ai_detected_count", "sum"),
).reset_index()
zone_stats["present_rate"] = zone_stats["present"] / zone_stats["scans"]
zone_stats["zone_risk"] = zone_stats["present_rate"].apply(
    lambda r: "High" if r >= 0.6 else ("Medium" if r >= 0.3 else "Low")
)
zone_stats = zone_stats.sort_values("present_rate", ascending=False)

plt.figure(figsize=(10, 5))
sns.barplot(data=zone_stats, x="zone", y="present_rate", hue="zone_risk", palette="Set1")
plt.title("Graph 5 — Zone risk (present rate per monitoring zone)")
plt.ylabel("Present rate")
plt.ylim(0, 1)
plt.xticks(rotation=30)
plt.tight_layout()
plt.savefig("graph5_zone_risk.png", dpi=300)
plt.show()
print(zone_stats)

# %% Cell 10 — Graph 6: Severity + confidence bands (app analytics)
fig, axes = plt.subplots(1, 2, figsize=(12, 4))
sns.countplot(data=df, x="severity", order=["Low", "Medium", "High"], ax=axes[0], palette="Oranges")
axes[0].set_title("Severity by ai_detected_count (≥15 High, ≥5 Medium)")
sns.countplot(data=df, x="confidence_band", ax=axes[1], palette="viridis")
axes[1].set_title("Confidence bands (74% / 20% policy)")
axes[1].tick_params(axis="x", rotation=25)
plt.tight_layout()
plt.savefig("graph6_severity_and_confidence_bands.png", dpi=300)
plt.show()

# %% Cell 11 — Download
from google.colab import files as dl
for f in [
    "graph1_class_distribution.png",
    "graph2_confidence_distribution.png",
    "graph3_confusion_matrix.png",
    "graph4_detection_trend.png",
    "graph5_zone_risk.png",
    "graph6_severity_and_confidence_bands.png",
]:
    dl.download(f)
