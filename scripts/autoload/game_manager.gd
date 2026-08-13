extends Node
## GameManager — global state: level progression, DSA puzzles, stats.

signal level_completed(level_index: int)
signal puzzle_solved(level_index: int)

## Ordered list of level scenes (must match file paths).
const LEVELS: Array[String] = [
	"res://scenes/levels/level_01_terminal.tscn",
	"res://scenes/levels/level_02_servers.tscn",
	"res://scenes/levels/level_03_core.tscn",
]

## Which levels have been unlocked (index 0 always unlocked).
var unlocked_levels: Array[bool] = [true, false, false]
## Best completion time per level (seconds), -1 = not completed.
var best_times: Array[float] = [-1.0, -1.0, -1.0]
## Number of data chips collected per level.
var chips_collected: Array[int] = [0, 0, 0]
## Total chips in each level (set by the level scene on load).
var chips_total: Array[int] = [0, 0, 0]
## Correct puzzle answers given (successes), keyed by level index.
var puzzles_solved: Array[bool] = [false, false, false]
var puzzles_attempted: int = 0

func _ready() -> void:
	randomize()
	load_game()

## Current level index (0-based).
var current_level: int = 0

## DSA puzzle bank. Each entry is a LeetCode-style problem.
## Fields: id, title, difficulty, description, options[], correct_index, explanation, hint
const PUZZLES: Array[Dictionary] = [
	{
		"id": "two_sum",
		"title": "Two Sum",
		"difficulty": "EASY",
		"description": "Given an array of integers `nums` and an integer `target`, return indices of the two numbers that add up to `target`.\n\nWhich approach gives the best time complexity?",
		"options": [
			"O(n²) — check every pair with nested loops",
			"O(n) — one pass with a hash map of seen values",
			"O(n log n) — sort first, then binary search",
			"O(1) — you cannot do better than constant time",
		],
		"correct_index": 1,
		"explanation": "A hash map gives O(n) time and O(n) space — each element is checked once: if target - nums[i] exists in the map, return. Nested loops would be O(n²), which is fine only for tiny inputs.",
		"hint": "As you walk the array, remember every value you've already seen — and ask what number you're missing.",
	},
	{
		"id": "valid_parentheses",
		"title": "Valid Parentheses",
		"difficulty": "EASY",
		"description": "Given a string s containing just the characters ( ) { } [ ], determine if the input string is valid: open brackets must be closed by the same type and in the correct order.\n\nWhich data structure is the classic fit?",
		"options": [
			"A hash map storing character counts",
			"A queue (FIFO) — process left to right",
			"A stack (LIFO) — push open brackets, pop and match on close",
			"A binary search tree for range queries",
		],
		"correct_index": 2,
		"explanation": "A stack is the natural fit: push every opening bracket; when you see a closing bracket, pop the top and verify it matches. This gives O(n) time and O(n) space. Counters alone can't verify *ordering*.",
		"hint": "The last opening bracket must match the first closing bracket you see — that's last-in, first-out behavior.",
	},
	{
		"id": "max_subarray",
		"title": "Maximum Subarray",
		"difficulty": "MEDIUM",
		"description": "Given an integer array nums, find the contiguous subarray (containing at least one number) which has the largest sum and return its sum.\n\nWhat is the best time complexity achievable?",
		"options": [
			"O(n²) — try every start/end pair",
			"O(n) — Kadane's algorithm: keep running sum, reset to 0 when negative",
			"O(n log n) — divide and conquer",
			"O(1) — it is always the maximum single element",
		],
		"correct_index": 1,
		"explanation": "Kadane's algorithm is O(n): maintain current_sum and best_sum; if current_sum drops below 0, reset it — a negative prefix can never help a future subarray. Divide & conquer is also correct but O(n log n).",
		"hint": "If your running total ever goes negative, it can only drag the next subarray down — start fresh.",
	},
	{
		"id": "reverse_linked_list",
		"title": "Reverse Linked List",
		"difficulty": "EASY",
		"description": "Given the head of a singly linked list, reverse the list and return the new head.\n\nWhat is the correct iterative pattern?",
		"options": [
			"Swap the head and tail values in place",
			"Use a stack, then pop in reverse order",
			"Three pointers: prev, curr, next — flip each node's next pointer",
			"Copy the list into an array and rebuild it",
		],
		"correct_index": 2,
		"explanation": "The classic iterative reverse uses prev/curr/next: save curr.next, point curr.next to prev, advance prev=curr and curr=saved_next. O(n) time, O(1) space. A stack works but costs O(n) extra space.",
		"hint": "You need to remember three nodes at once: the one before, the one you're flipping, and the one after.",
	},
	{
		"id": "binary_search",
		"title": "Binary Search",
		"difficulty": "EASY",
		"description": "Given a sorted array of n elements and a target value, find the index of the target.\n\nWhat invariant keeps binary search correct?",
		"options": [
			"The array must be unsorted — binary search works on any input",
			"Maintain lo and hi; mid = (lo + hi) / 2; narrow the search by comparing nums[mid] with target",
			"Always search from index 0 linearly",
			"Use a hash map of positions to avoid sorting",
		],
		"correct_index": 1,
		"explanation": "Binary search halves the search space each step: compare the middle element with the target, then discard the half that cannot contain it. Requires a sorted array, O(log n) time.",
		"hint": "Each step should throw away half of the remaining candidates.",
	},
	{
		"id": "merge_intervals",
		"title": "Merge Intervals",
		"difficulty": "MEDIUM",
		"description": "Given an array of intervals where intervals[i] = [start_i, end_i], merge all overlapping intervals and return an array of the non-overlapping intervals that cover all the intervals in the input.\n\nWhat is the first step that makes this tractable?",
		"options": [
			"Sort intervals by their end times",
			"Sort intervals by their start times, then merge greedily",
			"Build a prefix-sum table",
			"No sorting is needed — merge in any order",
		],
		"correct_index": 1,
		"explanation": "Sort by start time, then walk through: if the current interval overlaps the last merged one, extend it; otherwise push it. O(n log n) for the sort + O(n) merge.",
		"hint": "Order matters — put them in a line first, then decide which ones touch.",
	},
	{
		"id": "invert_binary_tree",
		"title": "Invert Binary Tree",
		"difficulty": "EASY",
		"description": "Given the root of a binary tree, invert the tree (swap every left and right child) and return its root.\n\nWhich traversal pattern is used in the classic recursive solution?",
		"options": [
			"In-order traversal, visiting nodes left → root → right",
			"Any traversal works: swap children at every node, recurse on both",
			"Only pre-order works; post-order fails",
			"Breadth-first only — recursion cannot invert a tree",
		],
		"correct_index": 1,
		"explanation": "Swap the left/right children at each node and recurse — this is correct for pre-order (swap then recurse) and post-order (recurse then swap). O(n) time where n is the number of nodes.",
		"hint": "At each node, the operation is the same: swap its two children.",
	},
	{
		"id": "top_k_frequent",
		"title": "Top K Frequent Elements",
		"difficulty": "MEDIUM",
		"description": "Given an integer array nums and an integer k, return the k most frequent elements.\n\nWhat is the best-complexity approach?",
		"options": [
			"Sort the array by value, then take the last k",
			"Count frequencies with a hash map, then use a heap of size k (or bucket sort) — O(n log k)",
			"Use a stack of size k",
			"Pick k random elements — frequency doesn't matter",
		],
		"correct_index": 1,
		"explanation": "Count with a hash map (O(n)), then a min-heap of size k keeps the top k in O(n log k). Bucket sort can reach O(n) time in the common case where counts are bounded.",
		"hint": "Two steps: tally everything, then keep only the k loudest voices.",
	},
	{
		"id": "lru_cache",
		"title": "LRU Cache",
		"difficulty": "MEDIUM",
		"description": "Design a data structure that follows the LRU (Least Recently Used) cache constraints: get and put must run in O(1) average time.\n\nWhich two data structures combined give O(1) get and put?",
		"options": [
			"A hash map alone",
			"A doubly-linked list alone",
			"A hash map + a doubly-linked list: map key → node, list tracks recency",
			"A binary search tree + an array",
		],
		"correct_index": 2,
		"explanation": "Hash map gives O(1) lookup by key; a doubly-linked list tracks recency order. On access, move the node to the head; on eviction, remove from the tail. This is the canonical LRU design.",
		"hint": "One structure finds the item, the other remembers the order you touched it in.",
	},
	{
		"id": "coin_change",
		"title": "Coin Change",
		"difficulty": "MEDIUM",
		"description": "You are given coins of different denominations and a total amount. Return the fewest number of coins needed to make up that amount.\n\nWhich algorithmic paradigm solves this optimally?",
		"options": [
			"Greedy — always take the largest coin first",
			"Dynamic programming — dp[i] = min number of coins for amount i, built bottom-up",
			"Binary search on the answer",
			"Topological sort of the denominations",
		],
		"correct_index": 1,
		"explanation": "DP bottom-up: dp[0]=0, and for each amount i, try each coin c: dp[i] = min(dp[i], dp[i-c]+1). O(amount × coins). Greedy fails for arbitrary denominations (e.g. coins [1,3,4], amount 6).",
		"hint": "The answer for amount i depends on the answer for smaller amounts — build from the bottom.",
	},
	{
		"id": "validate_bst",
		"title": "Validate Binary Search Tree",
		"difficulty": "MEDIUM",
		"description": "Given the root of a binary tree, determine if it is a valid BST (left subtree values < node < right subtree values, for every node).\n\nWhich check is sufficient?",
		"options": [
			"Check each node's children are smaller/larger — that's enough",
			"Pass down allowed min/max bounds for every subtree",
			"Check the tree is balanced",
			"Verify the root value is the median",
		],
		"correct_index": 1,
		"explanation": "Each node must respect a [min, max] range inherited from ancestors: left child is bounded by (min, node.val), right child by (node.val, max). Checking only direct children misses deep violations.",
		"hint": "A value in the right subtree of the root can never be smaller than the root — ancestors impose bounds.",
	},
	{
		"id": "longest_substring",
		"title": "Longest Substring Without Repeating Characters",
		"difficulty": "MEDIUM",
		"description": "Given a string s, find the length of the longest substring without repeating characters.\n\nWhat is the sliding-window pattern?",
		"options": [
			"Check every substring — O(n³)",
			"Two pointers (left/right): grow right, shrink left when a repeat appears — O(n)",
			"Reverse the string and compare",
			"Use a stack of characters",
		],
		"correct_index": 1,
		"explanation": "Slide a window: extend right and record chars in a set; when a duplicate appears, shrink from the left until it's gone. Each char enters/leaves once → O(n) time, O(min(n, alphabet)) space.",
		"hint": "Keep a window of unique characters — when a repeat sneaks in, cut the left edge until it's clean.",
	},
	{
		"id": "course_schedule",
		"title": "Course Schedule",
		"difficulty": "MEDIUM",
		"description": "There are numCourses courses you have to take, labeled 0 to numCourses - 1. Given prerequisites pairs, decide if you can finish all courses.\n\nWhat does this reduce to?",
		"options": [
			"Finding the longest path in the graph",
			"Cycle detection in a directed graph (topological sort / Kahn's algorithm)",
			"Computing connected components of an undirected graph",
			"Finding the minimum spanning tree",
		],
		"correct_index": 1,
		"explanation": "Prerequisites form a directed graph. If it contains a cycle, you can never finish. Detect cycles via DFS with three-color marking or Kahn's topological sort (O(V+E)).",
		"hint": "If one course needs another, and that one needs the first — you're stuck in a loop.",
	},
]

## Choose a puzzle for a level. Random pick from the bank (fresh each playthrough).
func get_puzzle_for_level(level_index: int) -> Dictionary:
	var pool := PUZZLES
	# Rotate difficulty by sector: sector 1 easy, sector 2 easy/medium, sector 3+ medium.
	var min_diff := 0
	var max_diff := PUZZLES.size() - 1
	match level_index:
		0:
			max_diff = 2   # two_sum, valid_parentheses, max_subarray (EASY/EASY/MEDIUM-ish)
		1:
			max_diff = 8
		2:
			min_diff = 4
	return pool[randi_range(min_diff, max_diff)]

func save_game() -> void:
	var cfg := ConfigFile.new()
	for i in range(unlocked_levels.size()):
		cfg.set_value("progress", "unlocked_%d" % i, unlocked_levels[i])
		cfg.set_value("progress", "best_time_%d" % i, best_times[i])
		cfg.set_value("progress", "chips_%d" % i, chips_collected[i])
		cfg.set_value("progress", "solved_%d" % i, puzzles_solved[i])
	cfg.save("user://save.cfg")

func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://save.cfg") != OK:
		return
	for i in range(unlocked_levels.size()):
		unlocked_levels[i] = cfg.get_value("progress", "unlocked_%d" % i, i == 0)
		best_times[i] = cfg.get_value("progress", "best_time_%d" % i, -1.0)
		chips_collected[i] = cfg.get_value("progress", "chips_%d" % i, 0)
		puzzles_solved[i] = cfg.get_value("progress", "solved_%d" % i, false)

func is_level_unlocked(level_index: int) -> bool:
	return unlocked_levels[level_index]

func complete_level(level_index: int, time_seconds: float, chips: int) -> void:
	if not puzzles_solved[level_index]:
		puzzles_solved[level_index] = true
		puzzle_solved.emit(level_index)
	if level_index + 1 < unlocked_levels.size():
		unlocked_levels[level_index + 1] = true
	if best_times[level_index] < 0.0 or time_seconds < best_times[level_index]:
		best_times[level_index] = time_seconds
	chips_collected[level_index] = chips
	save_game()
	level_completed.emit(level_index)
