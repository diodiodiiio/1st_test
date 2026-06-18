import numpy as np
import pytest

from face_similarity import (
    CommonalityResult,
    PairSimilarity,
    compute_commonality,
    cosine_similarity,
    similarity_score,
)


class TestCosineSimilarity:
    def test_identical_vectors(self):
        a = np.array([1, 0, 1, 0], dtype=np.float32)
        assert cosine_similarity(a, a) == pytest.approx(1.0, abs=1e-6)

    def test_opposite_vectors(self):
        a = np.array([1, 0, 1, 0], dtype=np.float32)
        b = np.array([-1, 0, -1, 0], dtype=np.float32)
        assert cosine_similarity(a, b) == pytest.approx(-1.0, abs=1e-6)

    def test_orthogonal_vectors(self):
        a = np.array([1, 0], dtype=np.float32)
        b = np.array([0, 1], dtype=np.float32)
        assert cosine_similarity(a, b) == pytest.approx(0.0, abs=1e-6)

    def test_known_value(self):
        # a=[1,0,1,0], b=[1,0,0,1] → cosine = 0.5
        a = np.array([1, 0, 1, 0], dtype=np.float32)
        b = np.array([1, 0, 0, 1], dtype=np.float32)
        assert cosine_similarity(a, b) == pytest.approx(0.5, abs=1e-6)

    def test_zero_vector_returns_zero(self):
        a = np.array([0, 0, 0], dtype=np.float32)
        b = np.array([1, 0, 0], dtype=np.float32)
        assert cosine_similarity(a, b) == 0.0

    def test_mismatched_shape_returns_zero(self):
        a = np.array([1, 0], dtype=np.float32)
        b = np.array([1, 0, 0], dtype=np.float32)
        assert cosine_similarity(a, b) == 0.0

    def test_2d_input_flattened(self):
        a = np.array([[1, 0], [1, 0]], dtype=np.float32)
        b = np.array([1, 0, 1, 0], dtype=np.float32)
        assert cosine_similarity(a, b) == pytest.approx(1.0, abs=1e-6)

    def test_result_clamped_to_minus_one(self):
        a = np.array([1.0], dtype=np.float64)
        b = np.array([-1.0], dtype=np.float64)
        assert cosine_similarity(a, b) >= -1.0

    def test_result_clamped_to_plus_one(self):
        a = np.array([1.0], dtype=np.float64)
        assert cosine_similarity(a, a) <= 1.0


class TestSimilarityScore:
    def test_identical_is_100(self):
        a = np.array([1, 0, 1, 0], dtype=np.float32)
        assert similarity_score(a, a) == pytest.approx(100.0, abs=1e-4)

    def test_opposite_is_0(self):
        a = np.array([1, 0, 1, 0], dtype=np.float32)
        b = np.array([-1, 0, -1, 0], dtype=np.float32)
        assert similarity_score(a, b) == pytest.approx(0.0, abs=1e-4)

    def test_orthogonal_is_50(self):
        a = np.array([1, 0], dtype=np.float32)
        b = np.array([0, 1], dtype=np.float32)
        assert similarity_score(a, b) == pytest.approx(50.0, abs=1e-4)

    def test_known_value_75(self):
        # cosine=0.5 → score=75
        a = np.array([1, 0, 1, 0], dtype=np.float32)
        b = np.array([1, 0, 0, 1], dtype=np.float32)
        assert similarity_score(a, b) == pytest.approx(75.0, abs=1e-4)

    def test_score_in_range(self):
        rng = np.random.default_rng(42)
        for _ in range(20):
            a = rng.standard_normal(128).astype(np.float32)
            b = rng.standard_normal(128).astype(np.float32)
            s = similarity_score(a, b)
            assert 0.0 <= s <= 100.0


class TestComputeCommonality:
    def _vec(self, *values: float) -> np.ndarray:
        return np.array(values, dtype=np.float32)

    def test_two_identical(self):
        a = self._vec(1, 0, 1, 0)
        result = compute_commonality([a, a])
        assert len(result.pairs) == 1
        assert result.overall_score == pytest.approx(100.0, abs=1e-4)

    def test_three_pairs_count(self):
        a = self._vec(1, 0, 1, 0)
        b = self._vec(1, 0, 0, 1)
        c = self._vec(-1, 0, -1, 0)
        result = compute_commonality([a, b, c])
        assert len(result.pairs) == 3
        assert result.image_count == 3

    def test_three_pairs_average(self):
        # scores: a-b=75, a-c=0, b-c=25 → avg=100/3
        a = self._vec(1, 0, 1, 0)
        b = self._vec(1, 0, 0, 1)
        c = self._vec(-1, 0, -1, 0)
        result = compute_commonality([a, b, c])
        assert result.overall_score == pytest.approx(100.0 / 3.0, abs=1e-4)

    def test_three_pairs_indices(self):
        vecs = [self._vec(1, 0), self._vec(0, 1), self._vec(1, 1)]
        result = compute_commonality(vecs)
        indices = {(p.first_index, p.second_index) for p in result.pairs}
        assert indices == {(0, 1), (0, 2), (1, 2)}

    def test_most_similar_pair(self):
        a = self._vec(1, 0, 1, 0)
        b = self._vec(1, 0, 0, 1)
        c = self._vec(-1, 0, -1, 0)
        result = compute_commonality([a, b, c])
        assert result.most_similar_pair is not None
        assert result.most_similar_pair.score == pytest.approx(75.0, abs=1e-4)

    def test_least_similar_pair(self):
        a = self._vec(1, 0, 1, 0)
        b = self._vec(1, 0, 0, 1)
        c = self._vec(-1, 0, -1, 0)
        result = compute_commonality([a, b, c])
        assert result.least_similar_pair is not None
        assert result.least_similar_pair.score == pytest.approx(0.0, abs=1e-4)

    def test_single_image_no_pairs(self):
        result = compute_commonality([self._vec(1, 0)])
        assert result.pairs == []
        assert result.overall_score == 0.0

    def test_empty_list_no_pairs(self):
        result = compute_commonality([])
        assert result.pairs == []
        assert result.overall_score == 0.0
        assert result.most_similar_pair is None
        assert result.least_similar_pair is None
