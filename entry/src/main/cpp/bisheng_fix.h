#ifndef BISHENG_FIX_H
#define BISHENG_FIX_H

#define _LIBCPP_STDEXCEPT
#define _LIBCPP___UTILITY_MOVE_H
#define _LIBCPP___UTILITY_PIECEWISE_CONSTRUCT_H
#define _LIBCPP___ALGORITHM_FIND_IF_H
#define _LIBCPP___ALGORITHM_HALF_POSITIVE_H
#define _LIBCPP___ALGORITHM_COMP_H
#define _LIBCPP___ALGORITHM_REVERSE_H
#define _LIBCPP___ALGORITHM_MAKE_HEAP_H
#define _LIBCPP___ALGORITHM_ADJACENT_FIND_H

#include <cerrno>
#include <type_traits>
#include <initializer_list>
#include <iosfwd>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR
typename remove_reference<_Tp>::type&& move(_Tp&& __t) _NOEXCEPT {
  typedef typename remove_reference<_Tp>::type _Up; return static_cast<_Up&&>(__t);
}
template <class _Tp>
using __move_if_noexcept_result_t =
    typename conditional<!is_nothrow_move_constructible<_Tp>::value && is_copy_constructible<_Tp>::value, const _Tp&, _Tp&&>::type;
template <class _Tp>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
__move_if_noexcept_result_t<_Tp> move_if_noexcept(_Tp& __x) _NOEXCEPT { return std::move(__x); }
struct _LIBCPP_TEMPLATE_VIS piecewise_construct_t { explicit piecewise_construct_t() = default; };
inline constexpr piecewise_construct_t piecewise_construct = piecewise_construct_t();

template <class _InputIterator, class _Predicate>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17 _InputIterator
find_if(_InputIterator __first, _InputIterator __last, _Predicate __pred) {
  for (; __first != __last; ++__first) if (__pred(*__first)) break; return __first;
}
template <typename _Integral>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR typename enable_if<is_integral<_Integral>::value, _Integral>::type
__half_positive(_Integral __value) { return static_cast<_Integral>(static_cast<typename make_unsigned<_Integral>::type>(__value) / 2); }
template <typename _Tp>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR typename enable_if<!is_integral<_Tp>::value, _Tp>::type
__half_positive(_Tp __value) { return __value / 2; }
template <class _T1, class _T2 = _T1> struct __less {
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11 bool operator()(const _T1& __x, const _T2& __y) const { return __x < __y; }
};
template <class _Tp> struct __less<_Tp, _Tp> {
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11 bool operator()(const _Tp& __x, const _Tp& __y) const { return __x < __y; }
};
template <class _ForwardIterator>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17 _ForwardIterator
adjacent_find(_ForwardIterator __first, _ForwardIterator __last) {
    if (__first != __last) { _ForwardIterator __i = __first; while (++__i != __last) { if (*__first == *__i) return __first; __first = __i; } } return __last;
}
template <class _AlgPolicy, class _ForwardIterator, class _BinaryPredicate>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17 _ForwardIterator
__adjacent_find(_ForwardIterator __first, _ForwardIterator __last, _BinaryPredicate __pred) {
    if (__first != __last) { _ForwardIterator __i = __first; while (++__i != __last) { if (__pred(*__first, *__i)) return __first; __first = __i; } } return __last;
}
template <class _AlgPolicy, class _BidirectionalIterator, class _Sentinel>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX17
void __reverse(_BidirectionalIterator __first, _Sentinel __last) {
    while (__first != __last) { if (__first == --__last) break;
        auto __tmp = std::move(*__first); *__first = std::move(*__last); *__last = std::move(__tmp); ++__first; }
}
template <class _AlgPolicy, class _Compare, class _RandomAccessIterator>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11
void __make_heap(_RandomAccessIterator __first, _RandomAccessIterator __last, _Compare&& __comp) {
    auto __n = __last - __first; if (__n > 1) {
        for (decltype(__n) __start = (__n - 2) / 2; __start >= 0; --__start) { decltype(__n) __i = __start;
            while (true) { decltype(__n) __child = 2 * __i + 1; if (__child >= __n) break;
                if (__child + 1 < __n && __comp(*(__first + __child), *(__first + __child + 1))) ++__child;
                if (!__comp(*(__first + __i), *(__first + __child))) break;
                auto __tmp = std::move(*(__first + __i)); *(__first + __i) = std::move(*(__first + __child));
                *(__first + __child) = std::move(__tmp); __i = __child; } } }
}

_LIBCPP_END_NAMESPACE_STD

#include <exception>

_LIBCPP_BEGIN_NAMESPACE_STD
class _LIBCPP_EXCEPTION_ABI logic_error : public exception {
public: _LIBCPP_INLINE_VISIBILITY explicit logic_error(const char* __s) _NOEXCEPT; virtual ~logic_error() _NOEXCEPT; virtual const char* what() const _NOEXCEPT;
};
class _LIBCPP_EXCEPTION_ABI runtime_error : public exception {
public: _LIBCPP_INLINE_VISIBILITY explicit runtime_error(const char* __s) _NOEXCEPT; virtual ~runtime_error() _NOEXCEPT; virtual const char* what() const _NOEXCEPT;
};
class _LIBCPP_EXCEPTION_ABI domain_error : public logic_error { public: _LIBCPP_INLINE_VISIBILITY explicit domain_error(const char* __s) : logic_error(__s) {} };
class _LIBCPP_EXCEPTION_ABI invalid_argument : public logic_error { public: _LIBCPP_INLINE_VISIBILITY explicit invalid_argument(const char* __s) : logic_error(__s) {} };
class _LIBCPP_EXCEPTION_ABI length_error : public logic_error { public: _LIBCPP_INLINE_VISIBILITY explicit length_error(const char* __s) : logic_error(__s) {} };
class _LIBCPP_EXCEPTION_ABI out_of_range : public logic_error { public: _LIBCPP_INLINE_VISIBILITY explicit out_of_range(const char* __s) : logic_error(__s) {} };
class _LIBCPP_EXCEPTION_ABI range_error : public runtime_error { public: _LIBCPP_INLINE_VISIBILITY explicit range_error(const char* __s) : runtime_error(__s) {} };
class _LIBCPP_EXCEPTION_ABI overflow_error : public runtime_error { public: _LIBCPP_INLINE_VISIBILITY explicit overflow_error(const char* __s) : runtime_error(__s) {} };
class _LIBCPP_EXCEPTION_ABI underflow_error : public runtime_error { public: _LIBCPP_INLINE_VISIBILITY explicit underflow_error(const char* __s) : runtime_error(__s) {} };
inline void __throw_length_error(const char*) {}
inline void __throw_out_of_range(const char*) {}
inline void __throw_runtime_error(const char*) {}
_LIBCPP_END_NAMESPACE_STD

// ============================================================
// Minimal basic_string replacement (SDK <string> class body
// is not emitted by BiSheng compiler at line 647+)
// ============================================================

_LIBCPP_BEGIN_NAMESPACE_STD

template<class _CharT, class _Traits, class _Allocator>
class _LIBCPP_TEMPLATE_VIS basic_string {
    _CharT* __data_;
    size_t __size_;
    size_t __cap_;
    static const _CharT __empty_[1];

    void __grow(size_t n) {
        if (n > __cap_) {
            size_t nc = __cap_ * 3 / 2;
            if (nc < n) nc = n;
            if (nc < 16) nc = 16;
            _CharT* nd = new _CharT[nc + 1];
            if (__data_ && __data_ != __empty_) {
                for (size_t i = 0; i < __size_; ++i) nd[i] = __data_[i];
                delete[] __data_;
            }
            __data_ = nd;
            __cap_ = nc;
            __data_[__size_] = 0;
        }
    }
    void __init(const _CharT* s, size_t n) {
        if (n) { __grow(n); for (size_t i = 0; i < n; ++i) __data_[i] = s[i]; __size_ = n; __data_[n] = 0; }
    }

public:
    typedef _CharT value_type;
    typedef value_type* iterator;
    typedef const value_type* const_iterator;
    typedef size_t size_type;
    static const size_type npos = size_type(-1);

    basic_string() : __data_(const_cast<_CharT*>(__empty_)), __size_(0), __cap_(0) {}
    basic_string(const _CharT* s) : basic_string() { if (s) { size_t n = 0; while (s[n]) ++n; __init(s, n); } }
    basic_string(const _CharT* s, size_t n) : basic_string() { __init(s, n); }
    basic_string(size_t n, _CharT c) : basic_string() { __grow(n); for (size_t i = 0; i < n; ++i) __data_[i] = c; __size_ = n; __data_[n] = 0; }
    basic_string(const basic_string& o) : basic_string() { __init(o.__data_, o.__size_); }
    basic_string(basic_string&& o) _NOEXCEPT : __data_(o.__data_), __size_(o.__size_), __cap_(o.__cap_) {
        o.__data_ = const_cast<_CharT*>(__empty_); o.__size_ = 0; o.__cap_ = 0;
    }
    ~basic_string() { if (__data_ && __data_ != __empty_) delete[] __data_; }

    basic_string& operator=(const basic_string& o) {
        if (this != &o) { clear(); __init(o.__data_, o.__size_); } return *this;
    }
    basic_string& operator=(basic_string&& o) _NOEXCEPT {
        if (__data_ && __data_ != __empty_) delete[] __data_;
        __data_ = o.__data_; __size_ = o.__size_; __cap_ = o.__cap_;
        o.__data_ = const_cast<_CharT*>(__empty_); o.__size_ = 0; o.__cap_ = 0;
        return *this;
    }

    _CharT& operator[](size_t i) { return __data_[i]; }
    const _CharT& operator[](size_t i) const { return __data_[i]; }
    const _CharT* data() const { return __data_; }
    const _CharT* c_str() const { return __data_; }
    size_t size() const { return __size_; }
    size_t length() const { return __size_; }
    bool empty() const { return __size_ == 0; }
    void reserve(size_t n) { __grow(n); }
    void resize(size_t n) {
        if (n > __size_) { __grow(n); for (size_t i = __size_; i < n; ++i) __data_[i] = 0; }
        __size_ = n; if (__data_ && __data_ != __empty_) __data_[n] = 0;
    }
    void clear() { __size_ = 0; if (__data_ && __data_ != __empty_) __data_[0] = 0; }
    basic_string& operator+=(_CharT c) {
        __grow(__size_ + 1); __data_[__size_++] = c; __data_[__size_] = 0; return *this;
    }
    basic_string& operator+=(const _CharT* s) {
        if (s) { size_t n = 0; while (s[n]) ++n; append(s, n); } return *this;
    }
    basic_string& assign(const _CharT* s, size_t n) { clear(); __init(s, n); return *this; }
    basic_string& append(const _CharT* s, size_t n) {
        if (n) { __grow(__size_ + n); for (size_t i = 0; i < n; ++i) __data_[__size_++] = s[i]; __data_[__size_] = 0; }
        return *this;
    }
    basic_string substr(size_t pos = 0, size_t count = npos) const {
        if (pos >= __size_) return basic_string();
        if (count > __size_ - pos) count = __size_ - pos;
        return basic_string(__data_ + pos, count);
    }
    iterator begin() { return __data_; }
    iterator end() { return __data_ + __size_; }
    const_iterator begin() const { return __data_; }
    const_iterator end() const { return __data_ + __size_; }
};

template<class _CharT, class _Traits, class _Allocator>
const _CharT basic_string<_CharT, _Traits, _Allocator>::__empty_[1] = {0};

// Note: string/u16string typedefs — SDK <string> has them at line 642
// but the class body area may not be emitted, so we provide them here.
typedef basic_string<char, char_traits<char>, allocator<char>> string;
typedef basic_string<char16_t, char_traits<char16_t>, allocator<char16_t>> u16string;

inline u16string operator+(const char16_t* lhs, const u16string& rhs) {
    u16string r(lhs); r.append(rhs.data(), rhs.size()); return r;
}

template <class _CharT, class _Traits = char_traits<_CharT>> class _LIBCPP_TEMPLATE_VIS basic_string_view;

_LIBCPP_END_NAMESPACE_STD

#include <__algorithm/find_end.h>
#include <__algorithm/minmax_element.h>

#endif