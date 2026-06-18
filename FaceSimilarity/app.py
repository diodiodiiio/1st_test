import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm

import streamlit as st
import numpy as np

from face_similarity import (
    bytes_to_bgr,
    compute_commonality,
    ensure_models,
    extract_embedding,
)

# Use IPAGothic for Japanese text in matplotlib plots
_ipa_fonts = [f.fname for f in fm.fontManager.ttflist if "IPAGothic" in f.name]
if _ipa_fonts:
    plt.rcParams["font.family"] = fm.FontProperties(fname=_ipa_fonts[0]).get_name()

st.set_page_config(page_title="顔の共通性診断", page_icon="👤", layout="wide")


@st.cache_resource(show_spinner="モデルを初期化中...")
def _load_models() -> bool:
    ensure_models()
    return True


_load_models()

st.title("👤 顔の共通性診断")
st.caption("複数の顔画像をアップロードして、顔の共通性・類似度を定量化します。")

uploaded_files = st.file_uploader(
    "顔画像をアップロード（2枚以上、JPG/PNG）",
    type=["jpg", "jpeg", "png"],
    accept_multiple_files=True,
)

if not uploaded_files:
    st.info("2枚以上の顔画像をアップロードしてください。")
    st.stop()

if len(uploaded_files) < 2:
    st.warning("比較には2枚以上の画像が必要です。")
    st.stop()

image_data = [(f.name, f.read()) for f in uploaded_files]

cols = st.columns(min(len(image_data), 6))
for i, (name, data) in enumerate(image_data):
    with cols[i % 6]:
        st.image(data, caption=f"画像 {i + 1}", use_container_width=True)

if st.button("🔍 共通性を分析する", type="primary"):
    embeddings: list[np.ndarray] = []
    labels: list[str] = []

    with st.spinner("顔を検出・解析中..."):
        for i, (name, data) in enumerate(image_data):
            bgr = bytes_to_bgr(data)
            if bgr is None:
                st.warning(f"画像 {i + 1}: 読み込みに失敗しました")
                continue
            emb = extract_embedding(bgr)
            if emb is None:
                st.warning(f"画像 {i + 1}: 顔が検出できませんでした")
            else:
                embeddings.append(emb)
                labels.append(f"画像 {i + 1}")

    if len(embeddings) < 2:
        st.error("比較できる顔が2枚以上必要です。顔がはっきり写った画像を使ってください。")
        st.stop()

    result = compute_commonality(embeddings)
    score = result.overall_score

    st.divider()
    st.subheader("📊 分析結果")

    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric("総合共通度スコア", f"{score:.1f}%")
    with col2:
        if result.most_similar_pair:
            p = result.most_similar_pair
            st.metric(
                "最も類似したペア",
                f"{labels[p.first_index]} ⇔ {labels[p.second_index]}",
                f"{p.score:.1f}%",
            )
    with col3:
        if result.least_similar_pair:
            p = result.least_similar_pair
            st.metric(
                "最も差があるペア",
                f"{labels[p.first_index]} ⇔ {labels[p.second_index]}",
                f"{p.score:.1f}%",
            )

    if score >= 75:
        st.success(f"💚 スコア {score:.1f}%: 顔の特徴が非常に類似しています")
    elif score >= 65:
        st.info(f"🔵 スコア {score:.1f}%: 比較的類似した顔の特徴があります")
    elif score >= 50:
        st.warning(f"🟡 スコア {score:.1f}%: やや類似した特徴があります")
    else:
        st.error(f"🔴 スコア {score:.1f}%: 顔の特徴が大きく異なります")

    st.subheader("ペアごとの類似度")
    for p in result.pairs:
        c1, c2 = st.columns([4, 1])
        with c1:
            st.write(f"**{labels[p.first_index]}** ⇔ **{labels[p.second_index]}**")
            st.progress(p.score / 100)
        with c2:
            st.metric("", f"{p.score:.1f}%", label_visibility="hidden")

    if len(embeddings) >= 3:
        st.subheader("類似度マトリックス")
        n = len(embeddings)
        matrix = np.full((n, n), 100.0)
        for p in result.pairs:
            matrix[p.first_index][p.second_index] = p.score
            matrix[p.second_index][p.first_index] = p.score

        fig, ax = plt.subplots(figsize=(max(4, n), max(4, n)))
        im = ax.imshow(matrix, cmap="RdYlGn", vmin=0, vmax=100)
        ax.set_xticks(range(n))
        ax.set_yticks(range(n))
        ax.set_xticklabels(labels, fontsize=10)
        ax.set_yticklabels(labels, fontsize=10)
        for i in range(n):
            for j in range(n):
                text_color = "black" if 30 < matrix[i][j] < 75 else "white"
                ax.text(j, i, f"{matrix[i][j]:.0f}%",
                        ha="center", va="center", fontsize=11, fontweight="bold",
                        color=text_color)
        plt.colorbar(im, ax=ax, label="類似度 (%)")
        ax.set_title("顔の類似度マトリックス", fontsize=13)
        plt.tight_layout()
        st.pyplot(fig)
        plt.close(fig)
