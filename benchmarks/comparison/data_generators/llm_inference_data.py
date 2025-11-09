"""
LLM Inference & RAG Data Generator

Generates realistic LLM API and RAG (Retrieval-Augmented Generation) usage data:
- API requests (completions, chat, embeddings)
- Token usage (input/output tokens)
- Latency metrics (TTFT, TPS, total latency)
- Cost tracking
- Cache hits/misses
- RAG retrieval metrics
- Model selection
"""

import random
import numpy as np
from datetime import datetime, timedelta
from typing import Iterator, List, Dict, Tuple, Optional
from dataclasses import dataclass
from enum import Enum


class RequestType(Enum):
    """Types of LLM API requests."""
    COMPLETION = "completion"
    CHAT = "chat"
    EMBEDDING = "embedding"
    RAG_QUERY = "rag_query"


class ModelName(Enum):
    """LLM model names."""
    GPT4 = "gpt-4"
    GPT4_TURBO = "gpt-4-turbo"
    GPT35_TURBO = "gpt-3.5-turbo"
    CLAUDE_3_OPUS = "claude-3-opus"
    CLAUDE_3_SONNET = "claude-3-sonnet"
    CLAUDE_3_HAIKU = "claude-3-haiku"
    GEMINI_PRO = "gemini-pro"
    LLAMA_70B = "llama-2-70b"


@dataclass
class InferenceRequest:
    """Single LLM inference request."""
    time: datetime
    request_id: str
    user_id: int
    request_type: str
    model_name: str
    input_tokens: int
    output_tokens: int
    total_tokens: int
    latency_ms: float
    ttft_ms: Optional[float]  # Time to first token
    tokens_per_second: Optional[float]  # Output generation speed
    cost_usd: float
    cache_hit: bool
    rag_retrieval_count: Optional[int]  # Number of documents retrieved (RAG only)
    rag_retrieval_time_ms: Optional[float]  # Time to retrieve documents
    status_code: int  # 200, 429 (rate limit), 500 (error), etc.


class LLMInferenceGenerator:
    """
    Generates realistic LLM inference and RAG data.

    Features:
    - Multiple request types (completion, chat, embedding, RAG)
    - Multiple models (GPT-4, Claude, Gemini, Llama)
    - Token usage patterns (short queries, long contexts)
    - Latency metrics (TTFT, tokens/sec)
    - Cost calculation per model
    - Cache simulation (20% hit rate)
    - RAG retrieval simulation
    - Rate limiting (429 errors)
    - Request patterns (bursty, circadian)
    """

    def __init__(self, seed: int = 42, num_users: int = 100000):
        """Initialize generator with random seed."""
        random.seed(seed)
        np.random.seed(seed)

        self.num_users = num_users

        # Model pricing (per 1M tokens)
        self.model_pricing = {
            ModelName.GPT4: {"input": 30.0, "output": 60.0},
            ModelName.GPT4_TURBO: {"input": 10.0, "output": 30.0},
            ModelName.GPT35_TURBO: {"input": 0.5, "output": 1.5},
            ModelName.CLAUDE_3_OPUS: {"input": 15.0, "output": 75.0},
            ModelName.CLAUDE_3_SONNET: {"input": 3.0, "output": 15.0},
            ModelName.CLAUDE_3_HAIKU: {"input": 0.25, "output": 1.25},
            ModelName.GEMINI_PRO: {"input": 0.5, "output": 1.5},
            ModelName.LLAMA_70B: {"input": 0.7, "output": 0.9}  # Self-hosted estimate
        }

        # Model performance (tokens/sec for output generation)
        self.model_speed = {
            ModelName.GPT4: (15, 25),
            ModelName.GPT4_TURBO: (30, 50),
            ModelName.GPT35_TURBO: (40, 70),
            ModelName.CLAUDE_3_OPUS: (20, 35),
            ModelName.CLAUDE_3_SONNET: (30, 50),
            ModelName.CLAUDE_3_HAIKU: (50, 80),
            ModelName.GEMINI_PRO: (35, 60),
            ModelName.LLAMA_70B: (25, 45)
        }

        self.request_counter = 0

        print(f"Initialized LLMInferenceGenerator with {num_users:,} users")

    def _generate_request_id(self) -> str:
        """Generate unique request ID."""
        self.request_counter += 1
        return f"req_{self.request_counter:016d}"

    def _select_request_type(self) -> str:
        """
        Select request type with realistic distribution.

        Distribution:
        - 50% chat
        - 30% completion
        - 15% RAG query
        - 5% embedding
        """
        types = list(RequestType)
        weights = [0.30, 0.50, 0.05, 0.15]
        return random.choices(types, weights=weights)[0].value

    def _select_model(self, request_type: str) -> str:
        """
        Select model based on request type.

        Different request types have different model preferences.
        """
        if request_type == RequestType.EMBEDDING.value:
            # Embeddings typically use specialized models (simulated here)
            return ModelName.GPT35_TURBO.value

        # For completions/chat/RAG
        models = list(ModelName)
        # GPT-3.5 and Claude Haiku most popular (cost-effective)
        weights = [0.10, 0.15, 0.30, 0.05, 0.15, 0.15, 0.05, 0.05]
        return random.choices(models, weights=weights)[0].value

    def _generate_input_tokens(self, request_type: str) -> int:
        """
        Generate input token count.

        Token counts follow log-normal distribution:
        - Short queries: 10-100 tokens
        - Medium contexts: 500-2000 tokens
        - Long contexts: 5000-32000 tokens
        """
        if request_type == RequestType.EMBEDDING.value:
            # Embeddings typically shorter
            return int(np.random.lognormal(4.5, 0.8))  # Mean ~100 tokens

        elif request_type == RequestType.CHAT.value:
            # Chat has mix of short and medium contexts
            if random.random() < 0.6:
                # Short conversation (60%)
                return int(np.random.lognormal(5.0, 0.6))  # Mean ~200 tokens
            else:
                # Long conversation with history (40%)
                return int(np.random.lognormal(7.0, 0.7))  # Mean ~1500 tokens

        elif request_type == RequestType.RAG_QUERY.value:
            # RAG has long contexts (retrieved documents)
            return int(np.random.lognormal(8.5, 0.6))  # Mean ~6000 tokens

        else:  # COMPLETION
            # Completions vary widely
            rand = random.random()
            if rand < 0.4:
                return int(np.random.lognormal(4.0, 0.7))  # Mean ~70 tokens
            elif rand < 0.8:
                return int(np.random.lognormal(6.5, 0.6))  # Mean ~800 tokens
            else:
                return int(np.random.lognormal(8.0, 0.7))  # Mean ~4000 tokens

    def _generate_output_tokens(self, request_type: str, input_tokens: int) -> int:
        """
        Generate output token count.

        Output length depends on input and request type.
        """
        if request_type == RequestType.EMBEDDING.value:
            # Embeddings have no output tokens
            return 0

        # Output typically shorter than input, but varies
        # Use fraction of input tokens as baseline
        base_output = input_tokens * random.uniform(0.1, 0.5)

        # Add noise
        output = int(base_output * np.random.lognormal(0, 0.5))

        # Clamp to reasonable range
        return max(min(output, 4096), 10)

    def _calculate_ttft(self, model_name: str, input_tokens: int) -> float:
        """
        Calculate Time To First Token (TTFT) in milliseconds.

        TTFT = prefill latency (process all input tokens)
        Depends on input length and model size.
        """
        model_enum = ModelName(model_name)

        # Base TTFT (larger models slower)
        base_ttft_ms = {
            ModelName.GPT4: 800,
            ModelName.GPT4_TURBO: 500,
            ModelName.GPT35_TURBO: 300,
            ModelName.CLAUDE_3_OPUS: 700,
            ModelName.CLAUDE_3_SONNET: 400,
            ModelName.CLAUDE_3_HAIKU: 200,
            ModelName.GEMINI_PRO: 350,
            ModelName.LLAMA_70B: 600
        }

        base = base_ttft_ms.get(model_enum, 400)

        # Scale with input length (linear)
        ttft = base + (input_tokens / 1000) * 100

        # Add variance
        ttft *= random.uniform(0.8, 1.2)

        return round(ttft, 2)

    def _calculate_generation_time(self, model_name: str, output_tokens: int) -> Tuple[float, float]:
        """
        Calculate output generation time and tokens/sec.

        Returns:
            (generation_time_ms, tokens_per_second)
        """
        model_enum = ModelName(model_name)

        # Get model speed range
        speed_range = self.model_speed.get(model_enum, (30, 50))
        tokens_per_sec = random.uniform(*speed_range)

        # Calculate generation time
        generation_time_ms = (output_tokens / tokens_per_sec) * 1000

        # Add variance
        generation_time_ms *= random.uniform(0.9, 1.1)

        return (round(generation_time_ms, 2), round(tokens_per_sec, 2))

    def _calculate_cost(self, model_name: str, input_tokens: int, output_tokens: int) -> float:
        """
        Calculate cost in USD based on token usage and model pricing.
        """
        model_enum = ModelName(model_name)
        pricing = self.model_pricing.get(model_enum, {"input": 1.0, "output": 2.0})

        input_cost = (input_tokens / 1_000_000) * pricing["input"]
        output_cost = (output_tokens / 1_000_000) * pricing["output"]

        return round(input_cost + output_cost, 6)

    def _should_cache_hit(self, input_tokens: int) -> bool:
        """
        Determine if request hits cache.

        Cache hit rate:
        - Short queries (< 500 tokens): 30% hit rate
        - Medium queries (500-2000 tokens): 20% hit rate
        - Long queries (> 2000 tokens): 10% hit rate
        """
        if input_tokens < 500:
            return random.random() < 0.30
        elif input_tokens < 2000:
            return random.random() < 0.20
        else:
            return random.random() < 0.10

    def _generate_rag_metrics(self) -> Tuple[int, float]:
        """
        Generate RAG retrieval metrics.

        Returns:
            (retrieval_count, retrieval_time_ms)
        """
        # Retrieve 3-10 documents
        retrieval_count = random.randint(3, 10)

        # Retrieval time depends on count
        # Base: 50ms, +20ms per document
        retrieval_time_ms = 50 + (retrieval_count * 20)

        # Add variance
        retrieval_time_ms *= random.uniform(0.8, 1.2)

        return (retrieval_count, round(retrieval_time_ms, 2))

    def _generate_status_code(self) -> int:
        """
        Generate HTTP status code.

        Distribution:
        - 98% success (200)
        - 1.5% rate limit (429)
        - 0.5% server error (500)
        """
        rand = random.random()

        if rand < 0.98:
            return 200
        elif rand < 0.995:
            return 429  # Rate limit
        else:
            return 500  # Server error

    def generate_requests(self, duration_seconds: int = 3600,
                         requests_per_second: int = 100) -> Iterator[InferenceRequest]:
        """
        Generate LLM inference request stream.

        Args:
            duration_seconds: How long to generate data for
            requests_per_second: Average requests per second

        Yields:
            InferenceRequest objects
        """
        start_time = datetime.now()
        current_time = start_time

        total_requests = duration_seconds * requests_per_second

        print(f"Generating ~{total_requests:,} inference requests...")
        print(f"  Duration: {duration_seconds}s ({duration_seconds/3600:.1f} hours)")
        print(f"  Rate: {requests_per_second:,} req/sec")

        requests_generated = 0

        for _ in range(duration_seconds):
            current_time += timedelta(seconds=1)

            # Generate requests for this second (with variance)
            requests_this_second = int(requests_per_second * random.uniform(0.8, 1.2))

            for _ in range(requests_this_second):
                # Generate request
                request_id = self._generate_request_id()
                user_id = random.randint(1, self.num_users)
                request_type = self._select_request_type()
                model_name = self._select_model(request_type)

                # Generate token counts
                input_tokens = self._generate_input_tokens(request_type)
                output_tokens = self._generate_output_tokens(request_type, input_tokens)
                total_tokens = input_tokens + output_tokens

                # Check cache hit
                cache_hit = self._should_cache_hit(input_tokens)

                # Calculate latency
                if request_type == RequestType.EMBEDDING.value:
                    # Embeddings have no TTFT or generation
                    ttft_ms = None
                    tokens_per_sec = None
                    latency_ms = random.uniform(50, 200)
                else:
                    # Calculate TTFT
                    ttft_ms = self._calculate_ttft(model_name, input_tokens)

                    # Calculate generation time
                    if output_tokens > 0:
                        generation_time_ms, tokens_per_sec = self._calculate_generation_time(
                            model_name, output_tokens
                        )
                    else:
                        generation_time_ms = 0
                        tokens_per_sec = None

                    # Total latency = TTFT + generation time
                    latency_ms = ttft_ms + generation_time_ms

                # Cache hits are 10x faster
                if cache_hit:
                    latency_ms *= 0.1
                    if ttft_ms:
                        ttft_ms *= 0.1

                # Calculate cost
                cost_usd = self._calculate_cost(model_name, input_tokens, output_tokens)

                # RAG-specific metrics
                if request_type == RequestType.RAG_QUERY.value:
                    rag_retrieval_count, rag_retrieval_time_ms = self._generate_rag_metrics()
                    # Add retrieval time to total latency
                    latency_ms += rag_retrieval_time_ms
                else:
                    rag_retrieval_count = None
                    rag_retrieval_time_ms = None

                # Generate status code
                status_code = self._generate_status_code()

                # If rate limited or error, latency is minimal
                if status_code != 200:
                    latency_ms = random.uniform(10, 100)

                yield InferenceRequest(
                    time=current_time,
                    request_id=request_id,
                    user_id=user_id,
                    request_type=request_type,
                    model_name=model_name,
                    input_tokens=input_tokens,
                    output_tokens=output_tokens,
                    total_tokens=total_tokens,
                    latency_ms=round(latency_ms, 2),
                    ttft_ms=ttft_ms,
                    tokens_per_second=tokens_per_sec,
                    cost_usd=cost_usd,
                    cache_hit=cache_hit,
                    rag_retrieval_count=rag_retrieval_count,
                    rag_retrieval_time_ms=rag_retrieval_time_ms,
                    status_code=status_code
                )

                requests_generated += 1

            # Progress update
            if requests_generated % 100_000 == 0:
                print(f"  Generated {requests_generated:,} requests...")

        print(f"✅ Generated {requests_generated:,} requests")

    def generate_dataset(self, size: str = "small") -> List[InferenceRequest]:
        """
        Generate complete dataset.

        Args:
            size: 'small' (1M rows), 'medium' (100M rows), 'large' (1B rows)

        Returns:
            List of InferenceRequest objects
        """
        # Calculate parameters based on size
        if size == "small":
            duration_seconds = 10000
            requests_per_second = 100
        elif size == "medium":
            duration_seconds = 1000000
            requests_per_second = 100
        elif size == "large":
            duration_seconds = 10000000
            requests_per_second = 100
        else:
            raise ValueError(f"Unknown size: {size}")

        requests = list(self.generate_requests(
            duration_seconds=duration_seconds,
            requests_per_second=requests_per_second
        ))

        return requests


def main():
    """Example usage and testing."""
    generator = LLMInferenceGenerator(seed=42, num_users=1000)

    # Generate 5 minutes of requests
    print("\nGenerating sample LLM inference data...")
    requests = list(generator.generate_requests(duration_seconds=300, requests_per_second=50))

    print(f"\n✅ Generated {len(requests):,} requests")
    print("\nSample requests (first 20):")

    for i, req in enumerate(requests[:20]):
        cache = "💾" if req.cache_hit else "  "
        ttft = f"TTFT:{req.ttft_ms:6.0f}ms" if req.ttft_ms else "           "
        tps = f"{req.tokens_per_second:.0f} tok/s" if req.tokens_per_second else "         "
        rag = f"RAG:{req.rag_retrieval_count}docs" if req.rag_retrieval_count else ""

        print(f"  {i+1}. {req.time.strftime('%H:%M:%S')} | {req.request_type:10s} | "
              f"{req.model_name:20s} | {req.input_tokens:5d}→{req.output_tokens:4d} tok | "
              f"{ttft} | {tps:9s} | ${req.cost_usd:.5f} | {cache} {rag}")

    # Statistics
    from collections import Counter

    print("\nRequest Type Distribution:")
    type_counts = Counter(r.request_type for r in requests)
    for req_type, count in type_counts.most_common():
        print(f"  {req_type:15s}: {count:5d} ({count/len(requests)*100:5.1f}%)")

    print("\nModel Distribution:")
    model_counts = Counter(r.model_name for r in requests)
    for model, count in model_counts.most_common():
        print(f"  {model:25s}: {count:5d} ({count/len(requests)*100:5.1f}%)")

    print("\nToken Usage Statistics:")
    print(f"  Avg input tokens: {np.mean([r.input_tokens for r in requests]):.0f}")
    print(f"  Avg output tokens: {np.mean([r.output_tokens for r in requests]):.0f}")
    print(f"  Total tokens processed: {sum(r.total_tokens for r in requests):,}")

    print("\nLatency Statistics:")
    latencies = [r.latency_ms for r in requests]
    print(f"  p50: {np.percentile(latencies, 50):.0f}ms")
    print(f"  p95: {np.percentile(latencies, 95):.0f}ms")
    print(f"  p99: {np.percentile(latencies, 99):.0f}ms")

    print("\nCost Analysis:")
    total_cost = sum(r.cost_usd for r in requests)
    print(f"  Total cost: ${total_cost:.2f}")
    print(f"  Avg cost per request: ${total_cost/len(requests):.5f}")

    print("\nCache Performance:")
    cache_hits = sum(1 for r in requests if r.cache_hit)
    print(f"  Cache hit rate: {cache_hits/len(requests)*100:.1f}%")

    print("\nRAG Statistics:")
    rag_requests = [r for r in requests if r.rag_retrieval_count]
    if rag_requests:
        print(f"  RAG requests: {len(rag_requests)}")
        print(f"  Avg retrieval count: {np.mean([r.rag_retrieval_count for r in rag_requests]):.1f} docs")
        print(f"  Avg retrieval time: {np.mean([r.rag_retrieval_time_ms for r in rag_requests]):.0f}ms")

    print("\nStatus Code Distribution:")
    status_counts = Counter(r.status_code for r in requests)
    for status, count in sorted(status_counts.items()):
        marker = "✅" if status == 200 else "❌"
        print(f"  {marker} {status}: {count:5d}")


if __name__ == "__main__":
    main()
